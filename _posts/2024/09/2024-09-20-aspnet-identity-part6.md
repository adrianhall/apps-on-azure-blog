---
title:  "ASP.NET Identity deep dive - Part 5 (Sending email)"
date:   2024-09-20
categories: dotnet
tags: [ csharp, aspnetcore, identity ]
header:
  image: "/assets/images/2024/09/2024-09-20-banner.png"
  teaser: "/assets/images/2024/09/2024-09-20-banner.png"
mermaid: true
---

This article is one of a number of articles I will write over the coming month and will go into depth about the [ASP.NET Identity](https://learn.microsoft.com/aspnet/core/security/authentication/identity) system.  My outline thus far:

{% include_relative includes/aspnet-identity-topics.html %}

Now that I have the basic flows sorted out (which includes username/password with registration, self-service password reset, and account lockout support), it's time to turn my attention to other aspects.  The first one I'm going to cover is social logins.  Why should your users remember yet another password?  Just redirect them to their favorite social media site, allow them to authenticate the user and redirect back.

## Required packages

ASP.NET Identity supports Facebook, Google, and Microsoft accounts out of the box.  There is another (extensive) set of libraries that cover everything else, including Amazon, Apple, Baidu, GitHub, LinkedIn, and pretty much anything else you need.  You can see [the list on their GitHub repository](https://github.com/aspnet-contrib/AspNet.Security.OAuth.Providers/tree/dev/src).  The first step is to add the correct libraries to your project:

```xml
<PackageReference Include="Microsoft.AspNetCore.Authentication.Facebook" Version="8.0.8" />
<PackageReference Include="Microsoft.AspNetCore.Authentication.Google" Version="8.0.8" />
<PackageReference Include="Microsoft.AspNetCore.Authentication.MicrosoftAccount" Version="8.0.8" />
<PackageReference Include="AspNet.Security.OAuth.LinkedIn" Version="8.2.0" />
```

Of course, I [centralized my dependencies]({% post_url 2024/08/2024-08-15-centrally-managing-dependencies %}) quite a while ago, so I don't define the versions in the project.

## Configuring clients

Before you start, there is *something* you need to do on the provider.  You'll need the URI of your identity service (likely `https://localhost:XXXX/` right now since you are probably still in development), then you'll need to go through a web-based sign-up to configure your client.

* [Facebook](https://learn.microsoft.com/aspnet/core/security/authentication/social/facebook-logins)
* [Google](https://learn.microsoft.com/aspnet/core/security/authentication/social/google-logins)
* [LinkedIn](https://learn.microsoft.com/linkedin/shared/authentication/client-credentials-flow?context=linkedin)
* [Microsoft](https://learn.microsoft.com/aspnet/core/security/authentication/social/microsoft-logins)

If you are intending on a different provider, you need to find out how to register for their developer program, register an application and get a **ClientId** and **ClientSecret**.  You'll also have to add the specific provider library from the `AspNet.Security.OAuth` collection of libraries.  

When you are configuring the client, note the following:

* Each provider has a specific "callback URI" that is based on your identity service.  For example, my server lives on `https://localhost:7186`; when configuring the client in the Azure portal, I needed to provide the "Redirect URI" as `https://localhost:7186/signin-microsoft` - That `/signin-microsoft` appended to your service URI is dependent on the library being used to configure the external provider.  Most have a default but allow you to configure it.
* Our primary mechanism for identifying  users is the email address.  If a user signs in with Facebook one day and their Microsoft account the next day, they shouldn't have to register again.  You will generally be asked what information (claims) you want to provide - always allow the email address.
* The generated client secret is a security token - make sure you protect it as such.  In production, store these in Azure Key Vault.  In development, store them in user-secrets.  **NEVER CHECK A SECURITY TOKEN INTO SOURCE CODE CONTROL**.

Once you have the client ID and client secret, add them to your user-secrets, like this:

```json
{
  "Identity": {
    "Facebook": {
      "ClientId": "4500b1ca-eef2-4fcc-9c03-7f3b1b195db6",
      "ClientSecret": "ZYDPLLBWSK3MVQJSIYHB1OR2JXCY0X2C5UJ2QAR2MAAIT5Q"
    },
    "Google": {
      "ClientId": "96fdd0e9-e4bc-4a99-816f-d4681092734d",
      "ClientSecret": "ZYDPLLBWSK3MVQJSIYHB1OR2JXCY0X2C5UJ2QAR2MAAIT5Q"
    },
    "LinkedIn": {
      "ClientId": "7ac05e1b-feb9-48aa-be27-c476c01e8568",
      "ClientSecret": "ZYDPLLBWSK3MVQJSIYHB1OR2JXCY0X2C5UJ2QAR2MAAIT5Q"
    },
    "MicrosoftAccount": {
      "ClientId": "d77083dd-36cf-4f6c-a09a-bbcba6797fcb",
      "ClientSecret": "ZYDPLLBWSK3MVQJSIYHB1OR2JXCY0X2C5UJ2QAR2MAAIT5Q"
    }
  }
}
```

Obviously, these values aren't real (which you will realize as soon as you generate your own - most of the values don't even look remotely similar to these).  Put your values in instead of these fake ones.  The only one I actually configured at this point was the Microsoft account.  The others held fake values in development just so I could see the icons.

## Update Program Startup

Up to this point, ASP.NET Identity hasn't needed to use `.AddAuthentication()`, but that changes todaya.  Here is the actual code I tend to use for configuring external clients:

```csharp
var identityBuilder = builder.Services.AddAuthentication();
IConfigurationSection fbCfg = builder.Configuration.GetSection("Identity:Facebook");
if (fbCfg.HasKey("ClientId") && fbCfg.HasKey("ClientSecret"))
{
    identityBuilder.AddFacebook(options =>
    {
        options.ClientId = fbCfg.GetRequiredString("ClientId");
        options.ClientSecret = fbCfg.GetRequiredString("ClientSecret");
    });
}

IConfigurationSection googleCfg = builder.Configuration.GetSection("Identity:Google");
if (googleCfg.HasKey("ClientId") && googleCfg.HasKey("ClientSecret"))
{
    identityBuilder.AddGoogle(options =>
    {
        options.ClientId = googleCfg.GetRequiredString("ClientId");
        options.ClientSecret = googleCfg.GetRequiredString("ClientSecret");
    });
}

IConfigurationSection msftCfg = builder.Configuration.GetSection("Identity:MicrosoftAccount");
if (msftCfg.HasKey("ClientId") && msftCfg.HasKey("ClientSecret"))
{
    identityBuilder.AddMicrosoftAccount(options =>
    {
        options.ClientId = msftCfg.GetRequiredString("ClientId");
        options.ClientSecret = msftCfg.GetRequiredString("ClientSecret");
    });
}

IConfiguration linkedInCfg = builder.Configuration.GetSection("Identity:LinkedIn");
if (linkedInCfg.HasKey("ClientId") && linkedInCfg.HasKey("ClientSecret"))
{
    identityBuilder.AddLinkedIn(options =>
    {
        options.ClientId = linkedInCfg.GetRequiredString("ClientId");
        options.ClientSecret = linkedInCfg.GetRequiredString("ClientSecret");
    });
}
```

I repeat ad-nauseum for each provider.  The extension methods `HasKey()` and `GetRequiredString()` allow me to avoid adding external providers that I am not using:

```csharp
public static string GetRequiredString(this IConfiguration configuration, string key)
    => configuration.HasKey(key) ? configuration[key]! : throw new KeyNotFoundException($"Configuration key '{key}' not found");

public static bool HasKey(this IConfiguration configuration, string key)
    => !string.IsNullOrWhiteSpace(configuration[key]);
```

## Update view models and Login action

I added the following to the `LoginViewModel`:

```csharp
public record LoginViewModel : LoginInputModel
{
    public LoginViewModel()
    {
    }

    public LoginViewModel(LoginInputModel inputModel) : base(inputModel)
    {
    }

    public IList<AuthenticationScheme> ExternalProviders { get; set; } = [];
}
```

That `ExternalProviders` will be populated with the list of, well, external providers.  Each provider has a name (Facebook, Google, Microsoft, LinkedIn) and a handler - these are wrapped in the `AuthenticationScheme` model.  I do need to populate it, though.  In my `AccountController`, I update `Login()` with the following:

```csharp
[HttpGet, AllowAnonymous]
public async Task<IActionResult> Login(string? returnUrl = null)
{
    returnUrl = HomePageIfNullOrEmpty(returnUrl);
    if (signInManager.IsSignedIn(User))
    {
        return RedirectToHomePage();
    }

    LoginViewModel viewModel = new()
    {
        ReturnUrl = returnUrl,
        ExternalProviders = (await signInManager.GetExternalAuthenticationSchemesAsync()).ToList(),
    };

    return View(viewModel);
}
```

Similarly, in the POST handler for the `Login()` action, I've got a "DisplayLoginView" method:

```csharp
  async Task<IActionResult> DisplayLoginView()
  {
      LoginViewModel viewModel = new(model)
      {
          ExternalProviders = (await signInManager.GetExternalAuthenticationSchemesAsync()).ToList(),
      };
      return View(viewModel);
  }
```

I call this method whenever I need to display the login view.  This ensures that whenever I display the login view, the `ExternalProviders` is populated with the right value.

## Update the login view

Before I update the login view, I want to establish some CSS for displaying the right icons.  Bootstrap Icons has icons for most of the social providers, so I'm using that.  Here is an example:

```scss
.auth-Microsoft {
    &::before {
        content: "\f65d";
    }
}
```

I'm going to construct this CSS class based on the name of the provider, so it has to match exactly.  You can look in `bootstrap-icons.css` (which will be in the `lib/bootstrap-icons/font` directory) for the value of the content field.  If you need an alternate icon, you can swap out the font.  Font Awesome has an extensive list of brand icons as well.

Back to the login view.  Here is the bit of code that I added:

```html
@if (Model.ExternalProviders.Any())
{
    <hr />
    <div class="container text-center">
        <h5 class="h5 text-gray-800 mb-1">Sign in with a social provider</h5>
    @foreach (AuthenticationScheme provider in Model.ExternalProviders.OrderBy(x => x.Name))
    {
        <a asp-controller="Account" asp-action="ExternalLogin" asp-route-returnUrl="@Model.ReturnUrl" asp-route-provider="@provider.Name" class="text-primary mx-2" style="font-size: 1.4rem; text-decoration: none;">
            <i class="bi auth-@provider.Name"></i>
        </a>
    }
    </div>
}
```

I'll probably clean this up at some point.  This displays a bunch of icons - one for each provider - and allows you to click on them.  When you click on them, it will open up `/Account/ExternalLogin?returnUrl=<your returnUrl>&provider=<provider-name>`, where `<provider-name>` is something like Facebook, Google, LinkedIn, or Microsoft.

At this point, you should be able to run the application and see the icons for you to click on when you go to the login page.  That should assure you that you've got the external logins configured correctly and that you've updated the login page appropriately.  I'm not a good web developer, so it took longer to get the HTML and CSS right than it did to configure the providers.

You will need one working external provider at this point.  I use the Microsoft provider since it's easy to configure with my Azure subscription.  The others all have dummy data in them just so I can ensure the icons appear correctly.

## The ExternalLogin actions

There are a bunch of actions required to handle external logins:

* `GET ExternalLogin` initiates the login process with the external provider, redirecting to the provider.
* `GET ExternalLoginCallback` handles the response from the external provider, including error handling and initiating external login registration.
* `GET ExternalLoginError` is a view action for displaying errors generated by the external login provider process.
* `POST RegisterExternalLogin` handles the form submission after the user has submitted the registration request.

Why do we need another registration request?

* A user might have (e.g.) their Facebook credentials compromised, and someone is impersonating them.  An email check will ensure the user has access to the email address.
* We need extra information (in my case, the display name, first name, and last name).  We can potentially pre-populate these from the external login claims, but still want to prompt the user for them.

I'm not going to cover the `ExternalLoginError` as it's simple.  The `RegisterExternalLogin` action is very similar to the `Register` action.  In fact, I used copy/paste for a lot of the code.  The `DisplayRegisterView()` uses a different view model, and there is some extra logic to inform ASP.NET Identity that the user uses external logins (also used in the `ExternalLoginCallback`).  However, you should be able to follow the code given your experience with the normal registration flow.

That leaves the two login mechanisms.  Let's look at the `GET ExternalLogin` action first:

```csharp
[HttpGet, AllowAnonymous]
public async Task<IActionResult> ExternalLogin([FromQuery] string? returnUrl, [FromQuery] string provider)
{
    returnUrl ??= Url.Content("~/");
    IList<AuthenticationScheme> authProviders = (await signInManager.GetExternalAuthenticationSchemesAsync()).ToList();
    if (!authProviders.Any(x => x.Name.Equals(provider)))
    {
        // If the provider is not known, then just go back to the login page.
        return RedirectToAction(nameof(Login), new { returnUrl });
    }

    string? redirectUrl = Url.ActionLink(nameof(ExternalLoginCallback), values: new { returnUrl });
    AuthenticationProperties properties = signInManager.ConfigureExternalAuthenticationProperties(provider, redirectUrl);
    return new ChallengeResult(provider, properties);
}
```

The login view provides links to this action with the provider set to the provider you want to use.  If the provider doesn't match one of the configured providers exactly, then we just redirect back to the login view.  If the provider does match, we construct a link to our callback action, then challenge the user to complete the authentication.  Behind the scenes, this will redirect over to the external provider with the configured client ID.  The user will then complete the authentication on the external providers site before being redirected back to your site.  The authentication subsystem will then lookup the redirect action and return control there.

The `ExternalLoginCallback` handles that response. Unlike the first time, the user is now authenticated.

```csharp
[HttpGet]
public async Task<IActionResult> ExternalLoginCallback(string? returnUrl = null, string? remoteError = null)
{
    returnUrl ??= Url.Content("~/");
    if (remoteError is not null)
    {
        TempData["ErrorMessage"] = $"Error from external provider: {remoteError}";
        return RedirectToAction(nameof(ExternalLoginError));
    }

    ExternalLoginInfo? info = await signInManager.GetExternalLoginInfoAsync();
    if (info is null)
    {
        TempData["ErrorMessage"] = "Error loading external login information";
        return RedirectToAction(nameof(ExternalLoginError));
    }

    // Sign the user in with this external login provider if the user already has a login.
    var result = await signInManager.ExternalLoginSignInAsync(info.LoginProvider, info.ProviderKey, isPersistent: false, bypassTwoFactor: true);
    if (result.Succeeded)
    {
        return Redirect(returnUrl);
    }

    if (result.IsLockedOut)
    {
        return RedirectToAction(nameof(LockedOut));
    }

    string email = string.Empty;
    if (info.Principal.HasClaim(c => c.Type == ClaimTypes.Email))
    {
        email = info.Principal.FindFirstValue(ClaimTypes.Email)!;
    }
    RegisterExternalLoginViewModel viewModel = new()
    {
        ReturnUrl = returnUrl,
        ProviderDisplayName = info.ProviderDisplayName,
        Email = email
    };
    return View(nameof(RegisterExternalLogin), viewModel);
}
```

When the user is returned to your application, you need to sign them in.  There is a new API (`ExternalLoginSignInAsync()`) that is used for signing a user into ASP.NET Identity with the external login information. One crinkle here - the user may not be registered with ASP.NET Identity.  In this case, the user can provide the rest of the information in the `RegisterExternalLogin` form and we have a view for that.

One notable thing here - we get an email address back from the external login provider, so we can pre-populate our form with that information.  We MAY also get other information.  For example, the external login provider may provide a first name and last name.  If they do, then you can use those to pre-populate your form.  You should still give the user an option of entering this additional information.

I did have to build the `RegisterExternalLoginInputModel` and `RegisterExternalLoginViewModel`.  The differences from the standard `RegisterViewModel`:

* I do not ask for a password when using an external login.
* There is an additional provider name that should be passed around for display purposes.

There are also two new views - one for displaying errors, and one that is a basic copy of the Register view.  However:

* I removed the password fields from the form.
* I made the email field a 'disabled' field.

I technically don't need to pass the email field around at all - it's in the user claims and can be retrieved at any time.  However, I feel it's a good idea to show it in samples.

You can check out the latest code changes at [my GitHub repository][github].

## Final thoughts

I like providing social logins.  It's one less password to remember and allows you to do other things (like social sharing).  However, there is almost as much complexity on the coding side for supporting social logins to supporting username and password logins.  Again, [Keycloak](https://www.keycloak.org/), [Auth0](https://auth0.com/), and [Corbado](https://www.corbado.com/) are still excellent options for you to integrate into your app that doesn't have the coding complexity of an identity solution.  You should seriously look at them as a solution!

# Further reading

* [The project so far][github].
* [Facebook Login for Developers](https://developers.facebook.com/products/facebook-login/)
* [Google Developers](https://developers.google.com/identity/sign-in/web/sign-in)
* [Sign in with LinkedIn](https://learn.microsoft.com/linkedin/consumer/integrations/self-serve/sign-in-with-linkedin-v2)
* [Microsoft Entra ID](https://learn.microsoft.com/aspnet/core/security/authentication/azure-active-directory/)
* [ASP.NET Identity](https://learn.microsoft.com/aspnet/core/security/authentication/social/)

And the ASP.NET Identity pages for social providers:

* [Facebook](https://learn.microsoft.com/aspnet/core/security/authentication/social/facebook-logins)
* [Google](https://learn.microsoft.com/aspnet/core/security/authentication/social/google-logins)
* [LinkedIn](https://learn.microsoft.com/linkedin/shared/authentication/client-credentials-flow?context=linkedin)
* [Microsoft](https://learn.microsoft.com/aspnet/core/security/authentication/social/microsoft-logins)

<!-- Links -->
[github]: https://github.com/adrianhall/samples/tree/0920/identity