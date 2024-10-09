---
title:  "Introducing the Datasync Community Toolkit - Day 1"
date:   2024-10-08
categories: datasync
tags: [ csharp, aspnetcore, datasync ]
image: "/assets/images/2024/10/2024-10-08-banner.png"
header:
  image: "/assets/images/2024/10/2024-10-08-banner.png"
  teaser: "/assets/images/2024/10/2024-10-08-banner.png"
mermaid: true
---

This article is the first in a series of articles about the [Datasync Community Toolkit][toolkit], which is a set of open source libraries for building client-server applications where the application data is available offline.  Unlike, for example, Firebase or AWS AppSync (which are two competitors in this space), the Datasync Community Toolkit allows you to connect to any database, use any authentication, and provides robust authorization rules.  You implement each side of the application (client and server) using .NET - ASP.NET Core Web APIs on the server side, and any .NET client technology (including WPF, WinUI, and MAUI) on the client side.

## What's the point of datasync?

With some applications, you don't get a choice.  If you are implementing a data gathering app where you expect data connectivity issues, data synchronization is a must have feature of the app.  However, you probably want to think about data synchronization as a feature in a wide variety of apps:

* **Resilience** - cellular networks are a shared resource.  IP addresses for connectivity change as you move and can drop completely in some areas.  If you want your data to be available while you move around, you have to build that in.  Data synchronization is one of the main techniques used to accomplish this goal.

* **Flexibility** - when you are using a data synchronization service, your data is stored within a local database.  You get a significant amount of flexibility in what you do to that database that you may not have when communicating with a server.  Updates are faster and you get a wider variety of search capabilities.

* **User experience** - the most important point of data synchronization is that your interactions with the user can be fulfilled faster than a round-trip to the server.  This benefits your users by making your application feel "snappier" because there is much much less latency involved.

Data synchronization is an overall benefit to your application, but it does come with some down sides.

* Identifiers must be globally unique.  It's normal for developers to say "an auto-incrementing integer ID is good enough" when setting up the database.  It isn't.  Take a case where you have two clients operating offline:

<pre class="mermaid">
sequenceDiagram
    Client1->>+Server: "Get *"
    Server->>+Client1: "No records"
    Client2->>+Server: "Create ID1"
    Server->>+Client2: "ID1 Created"
    Client2->>+Server: "GET *"
    Server->>+Client2: "[ID1]"
    Client1->>+Server: "Create ID1"
    Server->>+Client1: "409 ID1 Exists"
</pre>

As you can see from this basic transaction, whoever creates the first record causes conflicts for everyone coming afterwards.  Fortunately, .NET has globally unique IDs built in.  If you want to research better alternatives to the UUID, then you can take a look at [ULIDs](https://github.com/ulid/spec) and [Snowflake IDs](https://github.com/twitter-archive/snowflake/tree/b3f6a3c6ca8e1b6847baa6ff42bf72201e2c2231) as alternatives.  Both of these globally unique IDs are well supported with .NET community libraries.

* **Optimistic Concurrency** is a feature of datasync libraries that allows a client to accept a valid change in a disconnected state.  It checks for conflicts when the change is sent to the server.  This feature requires that an agreed upon concurrency check happens at the server for each change.  The change may be rejected if the concurrency check fails.

* **Incremental synchronization** is another feature of datasync libraries that is intended to reduce the bandwidth consumed by synchronization events.  It does this by only downloading the adds, changes, and deletions to the data set.  Incremental synchronization usually means that each data set must be isolated from the other synchronized data sets - no foreign keys are allowed.  This ensures that one data set can be updated without affecting other data sets.

* **Soft delete** is used by datasync libraries to ensure that deletions from the data set can be propagated to all clients and ensure data consistency.  It does this by including a "deleted" flag in the entity which is used to notify the client that the entity in question should no longer be considered.  This requires a clean-up process on the server to purge deleted records at a later date.

The net effect of these key features is that entities (or data transfer objects - DTOs) need to follow a specific pattern for implementation:

* Id - a globally unique string.
* UpdatedAt - a date/time with millisecond resolution to allow for isolated changes.
* Version - an opaque string that holds the concurrency token.
* Deleted - the soft deleted flag to indicate that an entity is deleted.

Underneath, the server is a standard ASP.NET Core Web API following RESTful techniques. Semantics included in [RFC9110](https://www.rfc-editor.org/rfc/rfc9110.html) - specifically sections 8 and 13 - provide optimistic concurrency.  An OData based query structure which allows for paging is used for data transfer.  By using a RESTful Web API, we get some benefits:

* You can test the API using [Postman], [Insomnia], or [Thunder Client] (among others).
* You can generate a Swagger definition, allowing easy integration into API management solutions.
* It integrates with standard OIDC type identity solutions for both authentication and authorization.
* You can write your own client.  The same service can be used for web, SPA, and mobile - even if it's not .NET based.  You don't have to use a specific client library.
* You can easily see the data using Wireshark, Charles, or other proxy technologies for debugging.

In short, you don't need to wonder whether a problem is in the client or server - the transaction can be seen, debugged, and the problem fixed.  Visibility wins!

## Your first datasync service

I'm not going to cover the datasync client today.  In fact, I won't be introducing the client for some time.  I'm going to cover the server in depth over the next few articles.  Today, however, I'm going to start the server from scratch and show you how easy it is to get started.

### It starts with a Web API project

Yes, you can do this all in Visual Studio.  Create a solution, then create a C# Web API project.  However, I like the command line:

```bash
mkdir datasync-sample
cd datasync-sample
dotnet new sln -n datasync-sample
dotnet new gitignore
mkdir Sample.WebAPI
cd Sample.WebAPI
dotnet new webapi
cd ..
dotnet sln ./datasync-sample.sln add ./Sample.WebAPI/Sample.WebAPI.csproj
```

You can run this on Mac, Linux, or Windows. You can edit this solution in Visual Studio, Visual Studio Code, or your editor of choice.  I'm using Visual Studio Community Edition, but you can use whatever you want.  Some of the instructions may change based on this.

### Web API + Entity Framework Core

Start by cleaning up the project.  Remove the model, http file, and controller or minimal API.  You need a blank canvas to work.  Now, let's add some NuGet packages to get started.  My project is going to be based on SQL Server, but this works equally well on MySQL, PostgreSQL, MongoDB, LiteDB, and Sqlite.  You can also use the Azure, AWS, or Google database offerings (although, personally, I've only used the Azure offerings).

```bash
cd Sample.WebAPI
dotnet add package Microsoft.EntityFrameworkCore.SqlServer
dotnet add package Microsoft.EntityFrameworkCore.Tools
dotnet add package CommuityToolkit.Datasync.Server
dotnet add package CommuityToolkit.Datasync.Server.EntityFrameworkCore
```

Next, let's set up a database.  For this, I'll need a model:

```csharp
using CommunityToolkit.Datasync.Server.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;

namespace Sample.WebAPI;

public class TodoItem : EntityTableData
{
    [Required, MinLength(1)]
    public string Title { get; set; } = string.Empty;

    public bool IsComplete { get; set; }
}
```

The `EntityTableData` base class holds the definitions of the entity metadata (`Id`, `UpdatedAt`, `Version`, and `Deleted`) since it's so common to use them.  I don't need to specify them for each model.  There are actually four different base classes:

* `EntityTableData` is used whenever the server can control `UpdatedAt` and `Version`.
* `CosmosEntityTableData` is used specifically for Cosmos DB.
* `SqliteEntityTableData` is used specifically for Sqlite.
* `RepositoryControlledEntityTableData` is used when the server cannot control `UpdatedAt` and `Version` - the repository we create later on will do that.

The [database tests](https://github.com/CommunityToolkit/Datasync/tree/main/tests/CommunityToolkit.Datasync.TestCommon/Databases) include a set of sample contexts and entity classes so you can see (for example) how to set up PostgreSQL or your favorite database.

Next, let's create a `DbContext`:

```csharp
using Microsoft.EntityFrameworkCore;

namespace Sample.WebAPI;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<TodoItem> TodoItems => Set<TodoItem>();
}
```

You'll  also need to deal with creating the database.  I'm not doing this for the sample - use migrations or SQL scripts or a bit of initializer code if you like.

> **The sample**<br/>
> You can find [a similar sample](https://github.com/CommunityToolkit/Datasync/tree/main/samples/datasync-server) with the Datasync Community Toolkit.  The official sample also
> supports deployment via the Azure Developer CLI so you can try it out in the cloud.

Next, let's wire in the database into our app:

```csharp
using CommunityToolkit.Datasync.Server;
using Microsoft.EntityFrameworkCore;
using Sample.WebAPI;

WebApplicationBuilder builder = WebApplication.CreateBuilder(args);

string connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? throw new ApplicationException("DefaultConnection is not set");

builder.Services.AddDbContext<AppDbContext>(options => options.UseSqlServer(connectionString));
builder.Services.AddDatasyncServices();
builder.Services.AddControllers();

WebApplication app = builder.Build();

// TODO: Initialize the database

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

app.Run();
```

This looks just like a regular web API project - because it is.  There is just one change I've added.  After the `AppDbContext` is added to services, I also `.AddDatasyncServices()`.  This is the only extra thing you **MUST** do during startup.  OData uses an `EdmModel` to understand the shape of the data that is being shared.  The `.AddDatasyncServices()` constructs the `EdmModel` for you so you don't have to worry about it.

Don't forget to add a `DefaultConnection` to your connection strings in `appsettings.Development.json` - something like this:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\mssqllocaldb;Database=TodoApp;Trusted_Connection=True"
  }
}
```

## Add a table controller

Most of the magic in this service is done within a controller.  No, you can't use minimal APIs.  The list operation is based on the standard OData library - which doesn't support minimal APIs.  Here is the most basic table controller:

```csharp
using CommunityToolkit.Datasync.Server;
using CommunityToolkit.Datasync.Server.EntityFrameworkCore;
using Microsoft.AspNetCore.Mvc;
using Sample.WebAPI;

namespace Sample.WebAPI.Controllers;

[Route("tables/[controller]")]
public class TodoItemController : TableController<TodoItem>
{
    public TodoItemController(AppDbContext context) 
        : base(new EntityTableRepository<TodoItem>(context))
    {
    }
}
```

This is undoubtedly the easiest way of generating a complete database based paged CRUD web API there is.  You do have some options here.  You can add a logger and set some controller options.  Here is a more fully featured version of the same controller:

```csharp
using CommunityToolkit.Datasync.Server;
using CommunityToolkit.Datasync.Server.EntityFrameworkCore;
using Microsoft.AspNetCore.Mvc;
using Sample.WebAPI;

namespace Sample.WebAPI.Controllers;

[Route("tables/[controller]")]
public class TodoItemController : TableController<TodoItem>
{
    public TodoItemController(AppDbContext context, ILogger<TodoItemController> logger) : base() 
        : base(new EntityTableRepository<TodoItem>(context))
    {
      Repository = new EntityTableRepository<TodoItem>(context);
      Logger = logger;
      Options = new TableControllerOptions 
      {
        DisableClientSideEvaluation = false,
        EnableSoftDelete = false,
        MaxTop = 128000,
        PageSize = 100,
        UnauthorizedStatusCode = 401
      };
    }
}
```

All the values in the options are the defaults.   Let's take a look at what each one means:

**DisableClientSideEvaluation** deals with something unique to the way LINQ interacts with database drivers.  You can write LINQ queries that cannot be fully executed on the database.  In this case a "client-side evaluation exception" is generated.  You don't know why it occurred.  It just means the database cannot evaluate the expression.  In this case, if `DisableClientSideEvaluation` is false, the ASP.NET Core server will attempt to work around the problem by doing a "client-side evaluation".  In this case, the ASP.NET Core server is the client-side (not your client - yes, it's confusing).   If `DisableClientSideEvaluation` is true, then the ASP.NET Core server will return a `500 Internal Server Error` response to the requesting application.

**EnableSoftDelete** affects what happens when the requesting application suggests deleting an entity.  If soft-delete is enabled, the entities `Deleted` flag will be set to true and that entity will not be considered unless deleted items are explicitly requested (which is a part of the synchronization process).

**MaxTop** affects how many records can be requested in one go.  It's the maximum value of the `$top` parameter in query operations.

**PageSize** is the maximum number of records that will be returned in one response.  We implement paging, so you can always get the next page and the next page - up to the biggest `$top` value.

**UnauthorizedStatusCode** affects what response is generated if the user is not authorized to read or write a record.  We'll get more into that next time.

That's the totality of a full server implementation for a simple one-table implementation.  To add further table controllers, just:

* Create the model (based on the same `EntityTableData`).
* Add the model to the `AppDbContext`.
* Create a table controller based on `TableController<TEntity>`.

## Bonus: Implement Swagger

Swagger is an important test tool since it allows you to see the definitions without any additional tooling - it's just a web page.  So let's do that.  In this case, I'm going to use [Swashbuckle].  It's the most popular tool.  You could use [NSwag] as well - both work just as well as each other.  Start by adding the right packages:

```bash
dotnet add package CommunityToolkit.Datasync.Server.Swashbuckle
```

This will also bring in the core Swashbuckle packages as transitive dependencies.  Next, update your `Program.cs`:

```csharp
// Where you set up your services:
builder.Services
  .AddEndpointsApiExplorer()
  .AddSwaggerGen(options => options.AddDatasyncControllers());

// Right after the .UseHttpsRedirection() call
app.UseSwagger().UseSwaggerUI();
```

Recompile and run your application. Then go to the `/swagger` endpoint for your server using your browser.  You'll see a nice UI for interacting with the REST interface.  Check out the definitions of the models and the endpoints you can access.

## How to interact with the server

You have five operations available now:

* **`POST /tables/items`** allows you to create an entity.  The data annotations for the entity will be checked (and your client will receive a 400 Bad Request if the data annotations check fails).  You do not (and should not) specify the metadata (`UpdatedAt`, `Version`, and `Deleted`).  You may specify an Id, but you don't have to.  If you don't specify an Id, one will be created for you.  The call will return the entity as it was stored in the database.  You can go and check it in the database after the call.  If you do specify an Id but it already exists, this will return a 409 Conflict response.

* **`GET /tables/items/{id}`** returns a JSON representation of the entity.  This is the same thing returned by the POST or PUT operations as well.  If the entity is marked as deleted, you will see a 410 Gone response. You may also get a 404 Not Found response if the entity is not in the database. If you get a 410 Gone response, you can use:

* **`GET /tables/items/{id}?__includedeleted=true`** also returns a JSON representation of the entity.  However, unlike the prior version, this version will return the entity if the entity happens to be marked as deleted.

* **`DELETE /tables/items/{id}`** which deletes an entity (or marks the entity as deleted). Unlike the other entities, this version will not return a 404 Not Found.  It will assume you are deleting it again and just say "yes, it no longer exists" - also known as 204 No Content in HTTP land.  This is the first of the operations where you can use conditional logic to ensure that the entity you are deleting has the same version as you expect (i.e. it has not changed since you downloaded it).  You do this with an If-Match header.  More on this in a bit.

* **`PUT /tables/items/{id}`** replaces an entity with new data.  Like `DELETE`, it support conditional headers.  Like `POST`, it returns the modified entity as stored in the database.  Like `GET`, you can specify that you should replace a deleted entity (in fact, this is how you "undelete" an entity after it has been marked for deletion).

* Finally, **`GET /tables/items`** gets the first page of items.  You can also use the following OData query parameters:

  * `$filter` specifies an OData filter, which is then translated into a LINQ query before being sent to the service.
  * `$select` specifies a list of properties that you want to return.
  * `$orderby` specifies the properties that you want to use for server-side sorting (including asc for ascending and desc for descending).
  * `$skip` tells the server to skip the first N matching entities.
  * `$top` tells the server to include the first N matching entities after the skip value.
  * `__includedeleted=true` tells the server to include entities that are marked for deletion.

The OData requirements give a lot of flexibility, but they really require a translator - we have a client package for that!

## Using conditional requests

Let's talk a little about conditional headers.  Let's say you have an entity that looks like this:

```http
// Request
POST /tables/items HTTP/1.1
Content-Type: application/json

{
  "title": "This is a test",
  "isComplete": false
}

// Response
201 Created
Link: https://localhost:1234/tables/items/t1
Content-Type: application/json

{
  "id": "t1",
  "updatedAt": "2024-12-24T08:00:00.123Z",
  "version": "AAAAAABB==",
  "deleted": false,
  "title": "This is a test",
  "isComplete": false
}
```

This is typical of a POST transaction.  The property names are "camel-case" by default.  You don't know what is behind that version string (technically, it's a base-64 encoded byte array managed by the database, but treat it as "do not touch").  Now, I want to update this entity on the server but only if it has not been changed.  I can do this:

```http
// Request
PUT /tables/items/t1 HTTP/1.1
Content-Type: application/json
If-Match: "AAAAAABB=="

{
  "id": "t1",
  "updatedAt": "2024-12-24T08:00:00.123Z",
  "version": "AAAAAABB==",
  "deleted": false,
  "title": "This is an update",
  "isComplete": false
}

// Response
200 OK
Content-Type: application/json

{
  "id": "t1",
  "updatedAt": "2024-12-25T09:30:00.456Z",
  "version": "AAAAAABC==",
  "deleted": false,
  "title": "This is an update",
  "isComplete": false
}
```

Note that you submit the SAME version (in a quoted string) as an `If-Match` header, and then you submit the new data (but with the same metadata) in the payload.  What comes back - the updated entity, which has a new version and the new updatedAt timestamp.  If someone else had done a change, you might get the following:

```http
// Request
PUT /tables/items/t1 HTTP/1.1
Content-Type: application/json
If-Match: "AAAAAABB=="

{
  "id": "t1",
  "updatedAt": "2024-12-24T08:00:00.123Z",
  "version": "AAAAAABB==",
  "deleted": false,
  "title": "This is an update",
  "isComplete": false
}

// Response
412 Precondition Failed
Content-Type: application/json

{
  "id": "t1",
  "updatedAt": "2024-12-25T09:30:00.456Z",
  "version": "AAAAAABC==",
  "deleted": false,
  "title": "This is an update",
  "isComplete": false
}
```

In this case, the response has a failure code and the content of the response contains the server version.  This is not the same as your version - it's a conflict.  You now have the client side version and the server side version.  You can decide what to do:

* To accept the client-side version, copy the version from the server-side into your client-side entity, then re-submit with the updated `If-Match` header.
* To accept the server-side version, just overwrite your client version.
* To pick and choose data, construct your new entity version using the servr-side version and updatedAt values, then re-submit with the updated `If-Match` header.

You want to re-submit with the updated `If-Match` header in case the server-side has changed since you received the conflict message.  You can also "force" the change by omitting the `If-Match` header.

## Final thoughts

Obviously, I've just scratched the surface of the Datasync Community Toolkit here.  In the next article, I'll cover a couple of other repository types and what you might use them for before moving onto authentication and authorization, writing your own repositories (which includes how to use auto-incrementing identities in your database), and some other common topics.  Once I've done that, I'll switch focus to the client-side of things and take a look at offline synchronization.

The Datasync Community Toolkit is an open source project that you can get involved in.  I have an ulterior motive here - I'm the maintainer.  But I welcome participants!

## Further reading

* [The Datasync Community Toolkit](https://communitytoolkit.github.io/Datasync/)
* [RFC 9110 - HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110.html)
* [The OpenAPI Specification (Swagger)](https://swagger.io/resources/open-api/)
* [Get started with Swashbuckle and ASP.NET Core][Swashbuckle]

<!-- Links -->
[toolkit]: https://github.com/CommunityToolkit/Datasync
[Postman]: https://www.postman.com/
[Insomnia]: https://insomnia.rest/
[Thunder Client]: https://www.thunderclient.com/
[Swashbuckle]: https://learn.microsoft.com/aspnet/core/tutorials/getting-started-with-swashbuckle
[NSwag]: https://learn.microsoft.com/aspnet/core/tutorials/getting-started-with-nswag