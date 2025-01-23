---
title:  "The Datasync Community Toolkit - Day 6: Client basics"
date:   2025-01-06
categories: datasync
tags: [ csharp, aspnetcore, datasync ]
image: "/assets/images/2025/01/2025-01-06-banner.png"
header:
  image: "/assets/images/2025/01/2025-01-06-banner.png"
  teaser: "/assets/images/2025/01/2025-01-06-banner.png"
---

This article is the sixth in a series of articles about the [Datasync Community Toolkit][toolkit], which is a set of open source libraries for building client-server applications where the application data is available offline. The Datasync Community Toolkit allows you to connect to any database, use any authentication, and provides robust authorization rules. You implement each side of the application (client and server) using .NET - [ASP.NET Core Web APIs](https://learn.microsoft.com/training/modules/build-web-api-aspnet-core/) on the server side, and any .NET client technology (including [WPF](https://wpf-tutorial.com/), [WinUI](https://learn.microsoft.com/windows/apps/winui/winui3/) and [MAUI](https://dotnet.microsoft.com/apps/maui)) on the client side.

This is the first article about the client-side of things.  If you missed the server-side articles, check out this set:

1. [Creating a service project]({% post_url 2024/10/2024-10-08-datasync-part1 %})
2. [The standard repositories]({% post_url 2024/10/2024-10-21-datasync-part2 %})
3. [Custom repositories]({% post_url 2024/11/2024-11-01-datasync-part3 %})
4. [Access control restrictions]({% post_url 2024/11/2024-11-12-datasync-part4 %})
5. [Real-time notifications]({% post_url 2024/11/2024-11-22-datasync-part5 %})

Over the next few weeks, I'll go over the basics - setting up an online client, switching to an offline client, modifying the offline client for a couple of specific use cases, and adding authentication to the process.  Each article will have an associated project you can use that is based on WPF (Windows Presentation Framework) and uses some of the other Community Toolkits as well.  You should be able to run the application against a local service each time.

You may remember from earlier articles that the service side of the component is merely a Web API that implements standard CRUD operations against a repository, along with an OData v4 query capability.  You don't need a special library.  In fact, my [web based todo app][todoapp-start] that is based on [TodoMVC] did nothing more than HTTP calls behind the scenes.

## The basic project

Todays topic is online operations, so I had better introduce todays sample as well.

There are two parts to todays sample - a service (which we will get to later) and a client.  As provided, the client works "offline only".  It uses an in-memory database that is recreated whenever the application is started.  There is no persistence.  How do you get it?

1. Download the [adrianhall/samples] repository.
2. Switch to the `datasync-day6` folder.
3. Open the solution file.
4. Build and run the `ClientApp` project.

> This project is based on the todoapp sample that is provided with the Community Datasync Toolkit, but has all the datasync code removed.

It's a good idea to take some time to understand this project before moving on.  The `MainWindow.xaml` contains all the UI code, and uses a `TodoListViewModel` to handle the interactions with the service.  The view model then calls methods within the `ITodoService` to do the database changes.  The `InMemoryTodoService` is a special implementation of the service that uses a concurrent dictionary to store the data.  There are four methods to implement:

* Get all items
* Get a single item by ID
* Add a new item
* Replace an existing item

It's worthwhile noting that I've set up the `TodoItem` model so that each entity contains the same metadata that we use for the server:

* `Id` is a globally unique ID stored as a string.
* `UpdatedAt` is the `DateTimeOffset` that the entity was last changed.
* `Version` is an opaque string that changes whenever the entity changes.
* `Deleted` is a boolean to indicate that the entity is deleted.

These are implemented in the `OfflineClientEntity` abstract clas - something you can use in your own projects.  Finally, everything is hooked up using the CommunityToolkit.MVVM project and dependency injection.

It's worthwhile taking some time to study the application prior to adding the datasync toolkit to it.  I won't be covering WPF application development.  You can also convert a similar application written in any C# client framework - including Avalonia, MAUI, WinUI, or the Uno Platform.  Theoretically, as long as it supports .NET8, it should work.  I haven't tried Unity (in fact, I've never written anything in Unity), and there may be side effects for other platforms that I haven't tried.  The majority will work, however.

## Online operations

Before we talk about offline operations (which is the topic for the next article), I'm going to talk about online operations.  I mentioned earlier that I had created the web version of this application using plain HTTP calls.  You also have the ability to use a client when using .NET.  I started by creating the basic TodoApp server (called ServerApp) running on `https://localhost:7181`, then configured the solution so that both server and client started concurrently.

The package to add for client operations is `CommunityToolkit.Datasync.Client` and it's available on NuGet.  Once added, you can easily set up a new `ITodoService` implementation that does the operations you need.  Let's take a look at the `OnlineTodoService` class that is included in the project:

```csharp
public class OnlineTodoService : ITodoService
{
    private const string baseUrl = "https://localhost:7181";
    private readonly DatasyncServiceClient<TodoItem> client;

    public OnlineTodoService()
    {
        var clientOptions = new HttpClientOptions()
        {
            Endpoint = new Uri(baseUrl)
        };
        client = new(clientOptions);
    }

    public async Task<TodoItem> AddTodoItemAsync(string title, CancellationToken cancellationToken = default)
    {
        ServiceResponse<TodoItem> response = await client.AddAsync(new TodoItem { Title = title }, cancellationToken);
        if (response.IsSuccessful && response.HasValue)
        {
            return response.Value!;
        }
        throw new ApplicationException(response.ReasonPhrase);
    }

    public async Task<List<TodoItem>> GetAllTodoItemsAsync(CancellationToken cancellationToken = default)
    {
        var list = await client.ToListAsync(cancellationToken);
        return list;
    }

    public async Task<TodoItem?> GetTodoItemAsync(string id, CancellationToken cancellationToken = default)
    {
        ServiceResponse<TodoItem> response = await client.GetAsync(id, cancellationToken);
        if (response.IsSuccessful && response.HasValue)
        {
            return response.Value!;
        }
        throw new ApplicationException(response.ReasonPhrase);
    }

    public async Task<TodoItem> ReplaceTodoItemAsync(TodoItem updatedItem, CancellationToken cancellationToken = default)
    {
        ServiceResponse<TodoItem> response = await client.ReplaceAsync(updatedItem, cancellationToken);
        if ( (response.IsSuccessful && response.HasValue)
        {
            return response.Value!;
        }
        throw new ApplicationException(response.ReasonPhrase);
    }
}
```

There are three things I want to point out here:

1. All access to the table is coordinated through a `DatasyncServiceClient<T>`.  You have a lot of options here, which I'll go through in a moment, but you need one of these for each table you access.  Since it's going across the network, it's best if this is placed in a singleton class.  We ensure that this class is a singleton within the dependency injection setup.
2. Three of the methods look almost identical.  Each of the methods that operates on a single entity returns a `ServiceResponse<T>`, so you have full access to the underlying HTTP response and can react accordingly.  In addition, the content is decoded and deserialized for you.  You have access to both the raw content and the deserialized content if appropriate. Use `.HasContent` and/or `.HasValue` to determine what was returned.
3. The client uses "LINQ-lite" for query operations - a subset of LINQ methods that are supported by the remote service.  You can't do joins, splits, and there is a very restrictive set of methods available for `.Where()`.  Don't assume that the full power of LINQ is available - it isn't.

Before I go on, change the service collection in `App.xaml.cs` to use the new service definition:

```csharp
  Services = new ServiceCollection()
      .AddSingleton<ITodoService, OnlineTodoService>()
      .AddTransient<TodoListViewModel>()
      .AddScoped<IAlertService, AlertService>()
      .AddScoped<IAppInitializer, AppInitializer>()
      .BuildServiceProvider();
```

Then run the server/client combination.  You can add an entity to the client application, then use the browser to browse to `https://localhost:7181/tables/todoitem` to see the stored item:

![Screenshot of the stored entity](/assets/images/2025/01/2025-01-06-image1.png)

## The many ways of setting up the client

The client library has got MANY ways of setting up the client.  Let's take a look at the choices you will be making:

### 1. How do I create a `HttpClient`?

The first thing to think about is how do I create a `HttpClient`?  All communication is routed through a `HttpClient` with a `BaseAddress` property set to the root of the server.  So you can just say something like this:

```csharp
HttpClient client = new HttpClient() { BaseAddress = new Uri("https://localhost:7181/") };
Uri relativeUri = new Uri("/tables/todoitem", UriKind.Relative);
DatasyncServiceClient<TodoItem> serviceClient = new(relativeUri, client);
```

This is perhaps the simplest mechanism there is.  The service client join the provided relativeUri to the base address of the client and that's the endpoint that will receive the communication.  Alternatively, you can just use a basic `HttpClient` and specify the URI absolutely:

```csharp
Uri tableUri = new Uri("https://localhost:7181/tables/todoitem");
DatasyncServiceClient<TodoItem> serviceClient = new(tableUri, new HttpClient());
```

However, we can also specify a list a delegating handlers to use (e.g. for logging, authentication, or adding API keys) and build a `HttpClient` ourselves.  We do this by using the `HttpClientOptions`:

```csharp
HttpClientOptions options = new() 
{
  Endpoint = new Uri("https://localhost:7181"),
  HttpPipeline = [
    LoggingDelegatingHandler(),
    AuthenticationDelegatingHandler()
  ],
  Timeout = TimeSpan.FromSeconds(60),
  UserAgent = "Datasync/Awesome-Datasync-Agent"
};
```

Once you have these options, you can create a `HttpClientFactory`, which is provided with the Community Datasync Toolkit:

```csharp
IHttpClientFactory factory = new HttpClientFactory(options);
HttpClient httpClient = factory.CreateClient();
Uri relativeUri = new Uri("/tables/todoitem", UriKind.Relative);
var serviceClient = new DatasyncServiceClient<TodoItem>(relativeUri, httpClient);
```

This gives you much flexibility in how you construct the client.  You can let the datasync library do it for you or you can tune every single aspect of the HTTP transaction.

### 2. JSON Serialization and Deserialization

I don't recommend you mess with the JSON serialization and deserialization settings.  They are configured to match what is provided by default with the Datasync server.  However, if you have added a converter to the server, you need to add the same converter to the client.  In this case, you can pass you new `JsonSerializerOptions` to the `DatasyncServiceClient<T>`:

```csharp
var serviceClient = new DatasyncServiceClient<TodoItem>(relativeUri, httpClient, jsonSerializerOptions);
```

## Operations that can be done online

You can do the following write operations online:

```csharp
// Add
var response = await serviceClient.AddAsync(clientSideItem, options);

// Delete
var response = await serviceClient.RemoveAsync(clientSideItem, options);

// Replace
var response = await serviceClient.ReplaceAsync(clientSideItem, options);
```

For each of these operations, you get a `ServiceResponse` or `ServiceResponse<T>` back.  There are also variations of these methods so that you can pick and choose which elements to use and how to set up the request.  In the case of a successful request, `response.IsSuccessful` will be true and if the operation is an Add or Replace, then `response.HasValue` will also be true and `response.Value` will contain the value of the entity that was stored in the server.  You should use this value instead of the client-side version you have been using.  You'll see how this is done in the example `OnlineTodoService`.

The options is type `DatasyncServiceOptions` and has the following properties:

* `ThrowIfMissing` will throw an exception if you ask to remove or replace an entity that does not exist.  If false, then you should check the ServiceResponse that is returned to determine success or failure.  This is useful when you are removing an entity and don't really care if the entity is missing or not.
* `IncludeDeleted`, when set to true, will also try to replace deleted items.  This allows you to "undelete" a soft-deleted record.
* `Version` is set to the version of the entity.  If not set, then the operation is forced.

By default, `Version` is set to the version of the entity, `IncludeDeleted` is false, and `ThrowIfMissing` is false.

Next, let's take a look at the read operations:

```csharp
// Get a single entity by Id
var response = await serviceClient.GetAsync(id, options);
```

Finally, there are lots more details on the query interface in [the documentation](https://communitytoolkit.github.io/Datasync/in-depth/client/online-operations/index.html#querying-for-data).  While "limited" by LINQ standards, it's still incredibly powerful.

## Wrap up

So, why start with online operations if this is a datasync library?  Firstly, figuring all the options that can be used to communicate with the server is important.  When things go wrong (and they will), figuring out what to do about it requires that you understand what is going on.  Switching to an online view (and adding logging) is a great way to get started.

Secondly, many applications require both online and offline capabilities - even in the lowly todo app.  Let's say I have categories and items.  All items belong to a category.  However, there are hundreds of categories and not all the categories are equally important.  I can do an online search for the categories I am interested in, then only pull records for those categories.  Similarly, I might have a list of all customers, but only synchronize customers I actively work with rather than all customers.

Having an online operation allows flexibility in creating my clients.

<!-- Links -->
[toolkit]: https://github.com/CommunityToolkit/Datasync
[adrianhall/samples]: https://github.com/adrianhall/samples
[todoapp-start]: https://github.com/adrianhall/samples/tree/1118/datasync-day5
[TodoMVC]: https://todomvc.com