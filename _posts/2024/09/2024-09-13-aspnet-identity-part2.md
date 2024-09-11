---
title:  "ASP.NET Identity deep dive - Part 2 (Registration)"
date:   2024-09-13
categories: dotnet
tags: [ csharp, aspnetcore, identity ]
header:
  image: "/assets/images/2024/09/2024-09-13-banner.png"
  teaser: "/assets/images/2024/09/2024-09-13-banner.png"
mermaid: true
---

This article is one of a number of articles I will write over the coming month and will go into depth about the [ASP.NET Identity](https://learn.microsoft.com/aspnet/core/security/authentication/identity) system.  My outline thus far:

* [Project setup]({% post_url 2024/09/2024-09-11-aspnet-identity-part1 %}).
* [Account registration]({% post_url 2024/09/2024-09-13-aspnet-identity-part2 %}).
* Email confirmation.
* Signing in and out with a username and password.
* Password reset.
* Social logins.
* Two-factor authentication.
* Going passwordless with magic links.

As you may remember from the [last article]({% post_url 2024/09/2024-09-11-aspnet-identity-part1 %}), the first user journey I am going to implement is the registration journey.  This is actually one of the more complex journeys with several parts to it.

<pre class="mermaid">
flowchart TD
  id1([User selects Register])
  id2[User Registration Form displayed]
  id3(User submits Registration Form)
  id4[User already exists]
  id5([User must be confirmed via email])
  id6(User clicks on email link)
  id7[User is confirmed]

  id1 --> id2
  id2 --> id3
  id3 --> id4
  id3 --> id5
  id5 --> id6
  id6 --> id7
</pre>

## Triggering registration

Let's get over some of the pre-requisites first.  When a user goes to my home page, I need to be able to trigger a registration event.  I started by gutting the `Views/Shared/_Layout.cshtml` file and establishing [my own Bootstrap configuration]({% post_url 2024-08-08-bootstrap-in-aspnetcore %}).  Part of that process was to create a navigation partial, which then includes the `Views/Shared/_LoginPartial.cshtml` file.  This uses ASP.NET Identity to decide what to display:

```html
@using Samples.Identity.Data
@using Microsoft.AspNetCore.Identity

@inject SignInManager<ApplicationUser> SignInManager
@inject UserManager<ApplicationUser> UserManager

@{
    bool isSignedIn = SignInManager.IsSignedIn(User);
    ApplicationUser? userRecord = await UserManager.GetUserAsync(User);
}

<ul class="navbar-nav ms-auto me-4 my-3 my-lg-0">
  @if (isSignedIn)
  {
    <a class="btn btn-primary rounded-pill px-3 mb-2 mb-lg-0" asp-controller="Account" asp-action="Logout">
      <span class="d-flex align-items-center">
        <i class="bi-person-circle me-2"></i>
        <span class="small">@userRecord?.DisplayName</span>
      </span>
    </a>
  }
  else
  {
    <a class="btn btn-primary px-3 mb-2 mx-2 mb-lg-0" asp-controller="Account" asp-action="Login">
      <span class="d-flex align-items-center">
        <i class="bi-box-arrow-in-right me-2"></i>
        <span class="small">Sign in</span>
      </span>
    </a>
    <a class="btn btn-warning px-3 mb-2 mb-lg-0" asp-controller="Account" asp-action="Register">
      <span class="d-flex align-items-center">
        <i class="bi-person-add me-2"></i>
        <span class="small">Register</span>
      </span>
    </a>
  }
</ul>
```

This is simple enough to follow.  I use the `SignInManager` (a part of ASP.NET Identity) to determine if the user is signed in or not.  I also retrieve the user record for the logged in user.  This will be null if the user is not logged in.  For the display part, I'm going to display the users display name (which I will capture during registration) and allow the user to sign out.  If the user is not signed in, then I'll display a sign in and a register button.

All three links go to actions within an `AccountController` - something I have not written yet.  MVC (model-view-controller) requires three parts - a model, a view, and a controller.  The `AccountController` is the controller part of this.

For the rest of this project, I'm going to be working on a number of files:

* `Controllers/AccountController.cs` is a C# class for handling the business logic for account operations.  We'll be adding a lot to this.
* `ViewModels/Account/*.cs` is a set of model classes for passing data to and from the views.
* `Views/Account/*.cshtml` are a set of views, written in Razor syntax, for displaying the output.

## Display the registration form

Let's start with the most basic sequence.  When a user pressed the register button, the `AccountController.Register()` method is called.  Let's take a look at the full `AccountController` at this point:

```csharp
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Samples.Identity.Data;
using Samples.Identity.Models.Account;

namespace Samples.Identity.Controllers;

[AutoValidateAntiforgeryToken]
public class AccountController(
    UserManager<ApplicationUser> userManager,
    SignInManager<ApplicationUser> signInManager,
    ILogger<AccountController> logger
    ) : Controller
{
    #region Register
    /// <summary>
    /// Displays the registration form
    /// </summary>
    [HttpGet]
    public IActionResult Register() => View(new RegisterViewModel());
    #endregion
}
```

The `UserManager<TUser>` and `SignInManager<TUser>` are from ASP.NET Identity. Finally, we have a logger since I do a lot of logging within the identity system.  For the actual page, I just display the view with a blank register view model.  I am using the standard anti-forgery token validation that is recommended for non-API scenarios across the entire controller.  You can read about this in [the ASP.NET Core documentation](https://learn.microsoft.com/aspnet/core/security/anti-request-forgery).  It's a critical part of the security story for identity.

I've got a specific way of dealing with view models.  I create an input model and a view model inside the same file, where the view model derives from the input model.  The register view model will show you what I mean:

```csharp
namespace Samples.Identity.ViewModels.Account;

public record RegisterInputModel
{
  public RegisterInputModel()
  {
  }

  public RegisterInputModel(RegisterInputModel model)
  {
    Email = model.Email;
    Password = model.Password;
    ConfirmPassword = model.ConfirmPassword;
    DisplayName = model.DisplayName;
  }

  [Required, EmailAddress]
  public string? Email { get; set; }

  [Required, MinLength(1), MaxLength(100)]
  public string? DisplayName { get; set; }

  [Required, DataType(DataType.Password)]
  public string? Password { get; set; }

  [Required, DataType(DataType.Password)]
  [Compare(nameof(Password), ErrorMessage = "Password and confirmation must match")]
  public string? ConfirmPassword { get; set; }
}

public record RegisterViewModel : RegisterInputModel
{
  public RegisterViewModel() : base()
  {
  }

  public RegisterViewModel(RegisterInputModel inputModel) : base(inputModel)
  {
  }
}
```

Why do I do it this way?  It's a standard I have adopted to split the classes between an input model (which is just the properties I need when submitting a form) and an output (or view) model (which is the properties I need to render the form).  By providing a constructor that takes the input model, I can easily clone the data for the next display when there is an error.

Now, let's take a look at the view:

```html
@using Samples.Identity.Models.Account
@model RegisterViewModel
@{
    ViewBag.BodyClass = "layout--account";
    ViewBag.Title = "Create account";
    Layout = "_AccountLayout";
}

@section StyleSheets {
    <link rel="stylesheet" href="https://unpkg.com/bs-brain@2.0.4/components/registrations/registration-6/assets/css/registration-6.css"/>
}

<div class="row">
    <div class="col-12">
        <div class="mb-5">
            <h2 class="h3">Registration</h2>
            <h3 class="fs-6 fw-normal text-secondary m-0">Enter your details to register</h3>
        </div>
    </div>
</div>
<form method="post">
    <div asp-validation-summary="ModelOnly" class="text-danger"></div>
    <div class="row gy-3 overflow-hidden">
        <div class="col-12">
            <div class="form-floating mb-3">
                <input asp-for="DisplayName" class="form-control" placeholder="Display Name" required>
                <label asp-for="DisplayName" class="form-label">Display Name</label>
                <span asp-validation-for="DisplayName" class="text-danger"></span>
            </div>
        </div>

        <div class="col-12">
            <div class="form-floating mb-3">
                <input asp-for="Email" class="form-control" placeholder="name@example.com" required>
                <label asp-for="Email" class="form-label">Email</label>
                <span asp-validation-for="Email" class="text-danger"></span>
            </div>
        </div>
        <div class="col-12">
            <div class="form-floating mb-3">
                <input asp-for="Password" class="form-control" placeholder="Password" required>
                <label asp-for="Password" class="form-label">Password</label>
                <span asp-validation-for="Password" class="text-danger"></span>
            </div>
        </div>
        <div class="col-12">
            <div class="form-floating mb-3">
                <input asp-for="ConfirmPassword" class="form-control" placeholder="Confirm Password" required>
                <label asp-for="ConfirmPassword" class="form-label">Password</label>
                <span asp-validation-for="ConfirmPassword" class="text-danger"></span>
            </div>
        </div>
        <div class="col-12">
            <div class="d-grid">
                <button class="btn bsb-btn-2xl btn-primary" type="submit">Sign up</button>
            </div>
        </div>
    </div>
</form>
<div class="row">
    <div class="col-12">
        <hr class="mt-5 mb-4 border-secondary-subtle">
        <p class="m-0 text-secondary text-center">
            Already have an account?
            <a asp-controller="Acocunt" asp-action="Login" class="link-primary text-decoration-none">Sign in</a>
        </p>
    </div>
</div>
```

This is a very basic Razor form. I've got a unique layout for the account section, but the rest of this is standard MVC view stuff.  You can (and should) do more here.  Some of the things I look at are password strength meters and inline validation capabilities to ensure that as much is done by the browser as possible before sending the form to the backend for processing.

You should be able to run the project at this point, click on the Register button and see your form.  Now you can play with your view and layout as much as is needed to get it to display the way you want.  Here are some sites that I came across while developing this:

* [Material UI Kit](https://mdbootstrap.com/docs/standard/extended/login/)
* [Bootstrap example login form](https://getbootstrap.com/docs/5.3/examples/sign-in/)
* [Bootstrap brain registration form](https://bootstrapbrain.com/component/bootstrap-registration-form-code/)

Obviously, I used one of the registration form examples from this last site.  I found their code to be great to follow.

## Further reading

* [Mozilla Developer Network](https://developer.mozilla.org/) - essential reading for frontend devs.
* [ASP.NET MVC Forms tag helpers](https://learn.microsoft.com/aspnet/core/mvc/views/working-with-forms).




