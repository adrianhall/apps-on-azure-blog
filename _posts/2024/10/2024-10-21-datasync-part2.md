---
title:  "The Datasync Community Toolkit - Day 2: The standard repositories"
date:   2024-10-21
categories: datasync
tags: [ csharp, aspnetcore, datasync ]
image: "/assets/images/2024/10/2024-10-21-banner.png"
header:
  image: "/assets/images/2024/10/2024-10-21-banner.png"
  teaser: "/assets/images/2024/10/2024-10-21-banner.png"
mermaid: true
---

This article is the second in a series of articles about the [Datasync Community Toolkit][toolkit], which is a set of open source libraries for building client-server applications where the application data is available offline.  The Datasync Community Toolkit allows you to connect to any database, use any authentication, and provides robust authorization rules.  You implement each side of the application (client and server) using .NET - [ASP.NET Core Web APIs](https://learn.microsoft.com/training/modules/build-web-api-aspnet-core/) on the server side, and any .NET client technology (including [WPF](https://wpf-tutorial.com/), [WinUI](https://learn.microsoft.com/windows/apps/winui/winui3/) and [MAUI](https://dotnet.microsoft.com/apps/maui)) on the client side.

In [the first article]({% post_url 2024/10/2024-10-08-datasync-part1 %}), I introduced you to the Datasync Community Toolkit and walked through creating a datasync server based on an Entity Framework Core database.  I also covered all the general options for the repositories and showed how you can adjust the Entity Framework Core system for specific databases.  The datasync server works with more than just Entity Framework Core and today I will show off the other standard repositories.

## The In Memory Repository

When I started writing the datasync service, I needed a simple repository based in-memory to use when testing and I didn't want to be guessing if the problem was a problem with my code or a peculiarity of the Entity Framework Core libraries.  I wrote a simple in-memory repository to solve this.  It turns out that in-memory repositories are really useful when the data doesn't change very often, even if the data is stored in a database.  It's also useful for test applications before you add a database for persistent storage.

Let's start with a common situation - you have a set of categories that are used in your application.  The categories don't change much and the user can't change them.  This is an ideal situation for an in-memory repository.  The in-memory repository requires the `CommunityToolkit.Datasync.Server.InMemory` NuGet package.

First, let's define a new class for the model:

```csharp
public class CategoryDTO : InMemoryTableData
{
  [Required, StringLength(64, MinimumLength = 1)]
  public string CategoryName { get; set; } = string.Empty;
}
```

Create an initializer:

```csharp
public interface IDatasyncInitializer
{
  Task InitializeAsync(CancellationToken cancellationToken = default);
}

public class DatasyncInitializer(AppDbContext context, IRepository<CategoryDTO> repository) : IDatasyncInitializer
{
  public async Task InitializeAsync(CancellationToken cancellationToken = default)
  {
    IList<Category> categories = await context.Categories.ToListAsync();
    IList<CategoryDTO> seed = categories.Select(x => Convert(x)).ToList();
    
    IQueryable<CategoryDTO> queryable = await repository.AsQueryableAsync(cancellationToken);
    foreach (CategoryDTO dto in seed) 
    {
      if (!queryable.Any(x => x.CategoryName.Equals(dto.CategoryName, StringComparison.OrdinalIgnoreCase)))
      {
        await repository.CreateAsync(dto, cancellationToken);
      }
    }
  }

  private static CategoryDTO Convert(Category category) => new()
    {
      Id = category.MobileId,
      UpdatedAt = category.UpdatedAt ?? DateTimeOffset.UnixEpoch,
      Version = category.Version ?? Guid.NewGuid().ToByteArray(),
      Deleted = false,
      CategoryName = category.CategoryName
    };
}
```

I've obviously made this a little more complex than it needs to be. I've ensured that the database model is different from the data transfer object (or DTO), so I need to translate between them.

* My database model starts with an auto-incrementing ID, but my DTO requires a globally unique ID.  I create a MobileId field to solve this.
* My `UpdatedAt` is stored in the database but it might be null, so I ensure that I set it.
* Similarly, my `Version` may not be set, so I ensure it is set.
* My database model doesn't have a `Deleted` flag, so I provide one. 

> The term "DTO" refers to a "Data Transfer Object" - an object that is transferred between client and server.  It is so named to distinguish it from the database object (which normally carries the real entity name).  You will often see `Model` and `ModelDTO` as pairs.
> {: .notice--info}

In the `InitializeAsync()` method, I grab the data from the database.  Then I use my conversion method to create the "datasync equivalents" before adding those values directly to the repository (with some protection around creating duplicate values).

Next, add the repository to the services in `Program.cs`:

```csharp
builder.Services.AddSingleton<IRepository<CategoryDTO>, InMemoryRepository<CategoryDTO>>();
builder.Services.AddScoped<IDatasyncInitializer, DatasyncInitializer>();
```

Initialize the repository immediately after you build the web application.  Since I am using a `DbInitializer` as well, I can include the datasync initializer in the same area.  This is what mine looks like:

```csharp
TimeSpan allowedInitializationTime = TimeSpan.FromMinutes(5);
CancellationTokenSource cts = new();

using (AsyncServiceScope scope = app.Services.CreateAsyncScope())
{
    IDbInitializer dbInitializer = scope.ServiceProvider.GetRequiredService<IDbInitializer>();
    IDatasyncInitializer datasyncInitializer = scope.ServiceProvider.GetRequiredService<IDatasyncInitializer>();
    cts.CancelAfter(allowedInitializationTime);
    try
    {
        CancellationToken ct = cts.Token;
        await dbInitializer.InitializeAsync(ct);
        await datasyncInitializer.InitializeAsync(ct);
    }
    catch (OperationCanceledException)
    {
        throw new ApplicationException($"Initialization failed to complete within {allowedInitializationTime}");
    }
}
```

I normally put this into an extension method to aid readability of the `Program.cs` file.

All that is left to do is to create a datasync controller:

```csharp
[Route("tables/[controller]")]
public class CategoryController : TableController<CategoryDTO>
{
    public CategoryController(IRepository<CategoryDTO> repository, ILogger<CategoryController> logger)
        : base(repository)
    {
        Logger = logger;
    }
}
```

As I showed in the last article, you can use Swashbuckle to interact with the server.  You'll see that the `/tables/category` endpoint acts just like the database backed endpoint.  However, data does not get persisted to the database and all data is served from memory.

> You are probably wondering how to make this table "read-only" at this point.  The answer to your question is "Access Control Providers" and I will be covering that topic in depth in a later article.
> {: .notice--info}

## The Automapper Repository

The next repository type is the `Automapper` repository.  Unlike the Entity Framework Core repository and the in-memory repository, this repository wraps another repository; it transforms the data before it is stored and while it is being read from the database.

It's common to desire a separation from the database model to the DTO in application design.  Perhaps not all properties are relevant; you need to rename some properties on the way through; or you need to convert the type from one type to another.  AutoMapper is very flexible in this regard.

First, set up your Automapper.  In my case, this came down to:

* Install the `Automapper` NuGet package.
* Create a profile.  Here is mine:

  ```csharp
  using AutoMapper;

  namespace InMemoryDatasyncService.Models;

  public class TodoItemProfile : Profile
  {
      public TodoItemProfile()
      {
          CreateMap<TodoItem, TodoItemDTO>()
              .ForMember(dest => dest.UpdatedAt, opt => opt.NullSubstitute(DateTimeOffset.UnixEpoch))
              .ReverseMap();
      }
  }
  ```

  As with the in-memory example, I am ensuring the `UpdatedAt` property is set appropriately even when the database holds a null value.

* Install the profile into your services:

  ```csharp
  builder.Services.AddAutoMapper(typeof(TodoItemProfile));
  ```

You will need both a forward and a reverse map for each pair of database model and DTO.  You should take care to ensure that the conditions required for the datasync metadata are met - `UpdatedAt` must be unique within the table and have msec precision, the `Version` should be a byte array that changes on every write, and `Id` must be a globally unique string.  You can use any of the AutoMapper features, including custom type converters, custom resolvers, and null substitution to ensure that your conversion works properly.

Both the model and the DTO must be "datasync ready" - i.e. they must inherit from something that implements `ITableData`.  The model must be suitable for use with the underlying repository.  Obviously, I am not doing anything spectacular here.  However, a specific note that this is a great way to implement a "null substitute" so that your datasync service doesn't blow up when the `UpdatedAt` field is not set properly.

> **Test your Automapper profile**<br/>
> You should always write unit tests for your automapper profile to ensure that the model can be converted to and from a DTO, including when the data is not set.
> {: .notice--warning}

Now that I've got my profile, I can include an auto-mapped datasync controller.  The `AutomappedRepository` is in the `CommunityToolkit.Datasync.Server.Automapper` NuGet package.  Here is a typical controller:

```csharp
[Route("api/todoitem")]
public class AutomappedController : TableController<TodoItemDTO>
{
    public AutomappedController(IMapper mapper, AppDbContext context) : base()
    {
        var efrepo = new EntityTableRepository<TodoItem>(context);
        Repository = new MappedTableRepository<TodoItem, TodoItemDTO>(mapper, efrepo);
    }
}
```

I don't find the MappedTableRepository that useful since it wraps an existing repository, which means the database model must conform to the datasync standards.  In the next article, I'll take a look at custom repositories which don't have this restriction.

## The LiteDB Repository

Finally, I created a repository around [LiteDB](https://www.litedb.org/).  LiteDB is a serverless embedded database that is written entirely in .NET, so it's ideal for cases where you need "something" to be a database but you don't want to go to the effort of setting up a server.  [SQLite](https://sqlite.org/) also fits the bill here.  However, SQLite has some restrictions around data/time handling that make it unsuitable for datasync applications on the server.

> **Don't use SQLite on the server**<br/>
> SQLite does not support date/time types with millisecond accuracy.  This makes it unsuitable for use on the server.  (We work around it on clients, as you will see later in the series).  If you really must use SQLite, make sure you add EF Core value converters on the `UpdatedAt` and `Version` fields to ensure that they are stored properly.

Fortunately, LiteDB doesn't have these restrictions. It naturally stores date/times with an ISO-8601 conversion and millisecond accuracy.  The LiteDB can be used "in-memory" on "on-disk".  The basics are easy.  Set up the model:

```csharp
public class LiteItem : LiteDbTableData
{
  public string Title { get; set; }
  public bool IsComplete { get; set; }
}
```

Add the database to the services as a singleton:

```csharp
string liteDBConnectionString = builder.Configuration.GetConnectionString("LiteDB");
builder.Services.AddSingleton<LiteDatabase>(new LiteDatabase(liteDBConnectionString));
```

Then, build your controller:

```csharp
[Route("tables/[controller]")]
public class LiteItemController(LiteDatabase db) : TableController<LiteItem>(new LiteDbRepository<LiteItem>(db, "todoitems"))
{
}
```

I've found myself moving away from LiteDB to the in-memory repository or a PostgreSQL database (in Aspire projects), so this doesn't get much use any more.  However, it may be ideal for your purposes.

> **Singleton or scoped?**<br/>
> One of the decisions you will have to make is whether to make your repository scoped to the request or a singleton.  If you are using Entity Framework Core, you will want your repository to be scoped.  The easiest way to do that is to create the repository in the constructor of your table controller.  For all other repositories, it depends on if your data store is thread-safe.  If it isn't thread safe, use a singleton.  If it is thread safe, you'll get better performance using a scoped service.

## Final thoughts

The Datasync Community Toolkit has four standard repositories:

* Entity Framework Core
* In-Memory
* LiteDb
* AutoMapper

These cover a vast array of situations and likely will cover your situation as well. They get you started fast and efficiently while still being "production ready".

However, there are always those cases when one of the standard repositories doesn't work for you.  The canonical example is an existing database table which uses auto-incrementing integers for the key.  The pluggable architecture of the Datasync Community Toolkit also allows you to write your own repositories.  In the next article, I'm going to dive into how you do that and how you can use custom repositories for the specific example of handling an existing database table.

## Further reading

* [An example server for this article](https://github.com/adrianhall/samples/tree/1021/datasync-day2)
* [AutoMapper](https://docs.automapper.org/en/stable/)
* [LiteDb](https://www.litedb.org)
* [Database support in Datasync Community Toolkit](https://communitytoolkit.github.io/Datasync/in-depth/server/databases/index.html)

<!-- Links -->
[toolkit]: https://github.com/CommunityToolkit/Datasync