---
title:  "The Datasync Community Toolkit - Day 4: Access control"
date:   2024-11-12
categories: datasync
tags: [ csharp, aspnetcore, datasync ]
image: "/assets/images/2024/11/2024-11-12-banner.png"
header:
  image: "/assets/images/2024/11/2024-11-12-banner.png"
  teaser: "/assets/images/2024/11/2024-11-12-banner.png"
---

This article is the fourth in a series of articles about the [Datasync Community Toolkit][toolkit], which is a set of open source libraries for building client-server applications where the application data is available offline. The Datasync Community Toolkit allows you to connect to any database, use any authentication, and provides robust authorization rules. You implement each side of the application (client and server) using .NET - [ASP.NET Core Web APIs](https://learn.microsoft.com/training/modules/build-web-api-aspnet-core/) on the server side, and any .NET client technology (including [WPF](https://wpf-tutorial.com/), [WinUI](https://learn.microsoft.com/windows/apps/winui/winui3/) and [MAUI](https://dotnet.microsoft.com/apps/maui)) on the client side.

Thus far, I've [walked through creating a project]({% post_url 2024/10/2024-10-08-datasync-part1 %}) and [introduced you to the standard repositories]({% post_url 2024/10/2024-10-21-datasync-part2 %}) and [custom repositories]({% post_url 2024/11/2024-11-01-datasync-part3 %}). Repositories are designed to be generic and provide access to the data you want to synchronize to your downstream clients.  However, sometimes you need to alter what happens when something is known about the user doing the synchronization.  The Datasync Community Toolkit supports standard ASP.NET Core authentication and authorization, including Entra ID and ASP.NET Core Identity.

When you need to adjust the view or operations available on a per-user basis, you need to implement an Access Control Provider and attach it to your table controller.

## What is an Access Control Provider?

Let's start with the obvious question - what is an Access Control Provider?  This is a class you write to control access to the repository through the table controller.  It consists of three distinct parts:

1. A method that defines the view of the data that the user has.
2. A method that decides whether the user can perform the in-flight operation.
3. A method that is called before writing to the database to modify the in-flight entity.

To implement an access control provider, you implement `IAccessControlProvider<TEntity>`.  This is located in the `CommunityToolkit.Datasync.Abstractions` NuGet package so you can put the access control providers in a separate project if you so desire.

> There is a fourth element of an access control provider - the `PostCommitHook`.  This is used for event management (such as notifying clients of changes in real-time) and not used in access control scenarios.
> {: .notice--information}

## An example access control provider

Let's look at a quick example.  Let's say we had a model like this:

```csharp
public class Article : EntityTableData
{
  public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

  public string Content { get; set; }
}
```

You've already set up your repository and table controller:

```csharp
public class ArticleController : TableController<Article>
{
  public ArticleController(AppDbContext context, ILogger<ArticleController> logger) : base()
  {
    Repository = new EntityRepository<Article>(context);
    Logger = logger;
  }
}
```

So far, this is normal datasync stuff. Now, let's say we have some business rules:

* Anonymous users can only retrieve articles - no writing articles unless you are authenticated.
* Users can only download articles created in the last 30 days.

This will demonstrate the first two methods that we have to write.

```csharp
public class ArticleAccessControlProvider(IHttpContextAccessor contextAccessor) : IAccessControlProvider<Article>
{
  private bool IsAuthenticated { get => contextAccessor.HttpContext?.User?.Identity?.IsAuthenticated == true; }

  public Expression<Func<Article, bool>> GetDataView()
    => article => article.CreatedAt > DateTimeOffset.AddDays(-30);

  public ValueTask<bool> IsAuthorizedAsync(TableOperation op, Article? entity, CancellationToken cancellationToken = default)
    => ValueTask.FromResult(op == TableOperation.Query || op == TableOperation.Read || IsAuthenticated);

  public ValueTask PreCommitHookAsync(TableOperation op, Article entity, CancellationToken cancellationToken = default)
    => ValueTask.CompletedTask;

  public ValueTask PostCommitHookAsync(TableOperation op, TEntity entity, CancellationToken cancellationToken = default)
    => ValueTask.CompletedTask;
}
```

Let's look at the pieces of `IAccessControlProvider`:

* `GetDataView()` returns the thing you would normally put in a `.Where()` clause of a LINQ expression.  In fact, that's exactly what is done internally.
* `IsAuthorizedAsync()` is called when the table controller needs to do something to the data.
* `PreCommitHookAsync()` is called immediately prior to writing an entity to the database.
* `PostCommitHookAsync()` is called immediately after writing an entity to the database and is not used in access control scenarios.  It's useful to trigger other things though.

In this simple case, I've added `IsAuthenticated` as a property which returns true if the connection is authorized and false otherwise. This is used in the `IsAuthorizedAsync()` method to say "anyone can retrieve articles; only authenticated users can write articles."

To attach this to the table controller, you need to set the `AccessControlProvider` property.  Here is the new controller:

```csharp
[AllowAnonymous]
public class ArticleController : TableController<Article>
{
  public ArticleController(AppDbContext context, IAccessControlProvider<Article> accessControlProvider, ILogger<ArticleController> logger) : base()
  {
    Repository = new EntityRepository<Article>(context);
    Logger = logger;
    AccessControlProvider = accessControlProvider;
  }
}
```

Don't forget to register it with dependency injection:

```csharp
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<IAccessControlProvider<Article>, ArticleAccessControlProvider>();
```

Some additional notes:

* All the datasync work is done within an async context.  That means we have to be careful about accessing the `HttpContext` within the async methods.  The `IHttpContextAccessor` interface (and its associated services) is the right way to do this.  Inevitably, access control providers need to access the `HttpContext` for the `ClaimsPrincipal` representing the current user.
* If you need to read the user context, you **MUST** decorate your controller with either `AllowAnonymous` or `Authorize`.  If you find `HttpContext.User` is null even when authenticated, it's probable that you forgot this.

## A generic example: The personal table

Let's look at a common case - the personal table.  I tend to use the `TodoItems` API as a minimal example.  What would I need to do so that a user can only create, update, delete, and view their own items?  Well, an access control provider is an excellent solution here.  Let's start by modifying the entity:

```csharp
public interface IPersonalEntity
{
  string UserId { get; set; }
}

public class TodoItem : EntityTableData, IPersonalEntity
{
  [JsonIgnore]
  public string UserId { get; set; } = string.Empty;
  public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
  public string Title { get; set; } = string.Empty;
  public bool IsComplete { get; set; } = false;
}
```

Here, I've also defined an `IPersonalEntity` interface.  This allows me to ensure that the access control provider can be re-used for multiple entity types so long as the interface is followed. In the concrete implementation, I've excluded the UserId from being sent to the client application.  It isn't needed in this case. Now, let's look at the access control provider I have in mind:

```csharp
public class PersonalAccessControlProvider<TEntity>(IHttpContextAccessor contextAccessor) 
  : IAccessControlProvider<TEntity> where TEntity : ITableData where TEntity : IPersonalEntity
{
  private string? UserId { get => contextAccessor.HttpContext?.User?.Identity?.Name; }

  public Expression<Func<TEntity, bool>> GetDataView()
     => UserId is null ? x => false : x => x.UserId == UserId;

  public ValueTask<bool> IsAuthorizedAsync(TableOperation op, TEntity? entity, CancellationToken cancellationToken = default)
    => ValueTask.FromResult(op is TableOperation.Create || op is TableOperation.Query || entity.UserId == UserId);

  public ValueTask PreCommitHookAsync(TableOperation op, TEntity entity, CancellationToken cancellationToken = default)
  {
    entity.UserId = UserId;
    return ValueTask.CompletedTask;
  }

  public ValueTask PostCommitHookAsync(TableOperation op, TEntity entity, CancellationToken cancellationToken = default)
    => ValueTask.CompletedTask;
}
```

Let's walk through it.

* `UserId` is a property that pulls the current users ID from the identity `Name` property - this is normally correct, but may not be stable.  You may want to use (for example) `User?.FindFirstValue(ClaimTypes.Email)` as an alternative to make the user ID an email address instead.
* `GetDataView()` is careful to handle the case when the UserId is null to prevent leaking information.  The UserId of the entity to be returned must match the UserId of the user.
* `IsAuthorizedAsync()` allows the user to create new entities and read their own entities (since that's defined by `GetDataView()`).  Anything else requires that the UserId matches.
* Finally, `PreCommitHookAsync()` ensures that the entity UserId is set properly when storing the entity.  Since the user is not specifying the UserId, it will get set on create and update / replace operations (plus deletions when soft-delete is enabled).  Again, let's ignore `PostCommitHookAsync()` for now.

How do I use this?

```csharp
[Authorize]
public class TodoItemsController : TableController<TodoItem>
{
  public TodoItemsController(AppDbContext context, IHttpContextAccessor contextAccessor) : base()
  {
    Repository = new EntityTableRepository<TodoItem>(context);
    AccessControlProvider = new PersonalAccessControlProvider<TodoItem>(contextAccessor);
  }
}
```

Instead of injecting it into the service collection, I've just created a new one. Either way works and one is not better than the other.  Injecting the access control providers into the services collection has the advantage of dependency injection which can make management easier.

## Final thoughts

Access control providers are a good way to inject your specific business logic into the process.  I've created access control providers in the past for these scenarios:

* The CRM model (driven by database models)
  * On the Customers model, only allow the user to download the customer accounts that they own and disallow creation and deletion of customer accounts.
  * On the CustomerNotes model, only allow the user to create a note for a customer account they own; retrieve notes for customer accounts they own; disallow update/delete of notes.
* The Roles model (driven by ASP.NET Identity)
  * Administrators get to see everything; everyone else gets to see their own records.
  * Only designated individuals can delete records.
* The followers model
  * A personal table allowing the user to add/remove accounts that they follow.
  * Then an articles table that allows the user to see the articles for the accounts that they follow (which is done via a Join and a custom repository).

This system is highly flexible and allows you to customize what users can see and do at a very granular level.  The only gotcha really is when you are altering the view based on a database lookup.  In this case, it's generally a good idea to write a custom repository that returns the permissions data through a join.  This makes it available to you in the access control provider in a more efficient way.

Now, what was that about post commit hooks?  That's a topic for next time.

## Further reading

* [An example "personal" TodoItem service using Entra ID](https://github.com/adrianhall/samples/tree/1112/datasync-day4)
* [The documentation](https://communitytoolkit.github.io/Datasync/in-depth/server/index.html#configure-access-permissions)
* [IHttpContextAccessor](https://learn.microsoft.com/aspnet/core/fundamentals/http-context)

<!-- Links -->
[toolkit]: https://github.com/CommunityToolkit/Datasync