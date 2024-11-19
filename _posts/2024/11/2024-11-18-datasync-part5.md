---
title:  "The Datasync Community Toolkit - Day 5: Real-time updates"
date:   2024-11-18
categories: datasync
tags: [ csharp, aspnetcore, datasync ]
image: "/assets/images/2024/11/2024-11-18-banner.png"
header:
  image: "/assets/images/2024/11/2024-11-18-banner.png"
  teaser: "/assets/images/2024/11/2024-11-18-banner.png"
---

This article is the fifth in a series of articles about the [Datasync Community Toolkit][toolkit], which is a set of open source libraries for building client-server applications where the application data is available offline. The Datasync Community Toolkit allows you to connect to any database, use any authentication, and provides robust authorization rules. You implement each side of the application (client and server) using .NET - [ASP.NET Core Web APIs](https://learn.microsoft.com/training/modules/build-web-api-aspnet-core/) on the server side, and any .NET client technology (including [WPF](https://wpf-tutorial.com/), [WinUI](https://learn.microsoft.com/windows/apps/winui/winui3/) and [MAUI](https://dotnet.microsoft.com/apps/maui)) on the client side.

This is the last article about the server-side of things.  In the next article, I'll be looking at the client-side of things.

Thus far, I've [walked through creating a project]({% post_url 2024/10/2024-10-08-datasync-part1 %}), [introduced you to the standard repositories]({% post_url 2024/10/2024-10-21-datasync-part2 %}) and [custom repositories]({% post_url 2024/11/2024-11-01-datasync-part3 %}), and shown how you can implement [access-control restrictions]({% post_url 2024/11/2024-11-12-datasync-part4 %}). By now, you should be comfortable with creating a backend service.  To celebrate this, I've got [a nice todo app][todoapp-start] that is based on [TodoMVC].

> **Details of the TodoMVC implementation**
>
> * Start with an ASP.NET Core MVC application.
> * Add Entity Framework Core with your favorite database.
> * Integrate the Datasync Community Toolkit with the `TodoItem` model.
> * Add a [TodoMVC] JavaScript application using local storage for the store.
> * Create a `DatasyncService` inside the site Javascript that uses `fetch()` to call the table controller.
>
> Most of the code is in `wwwroot/site.js`.  You should be able to download the project, then press F5 to run the project.

## Implementing real-time notifications

One of the basic questions I get asked (a lot) is how you can go from a datasync service to a real-time datasync service.  Inevitably, the person asking is comparing with their experience with Firebase, Realm, or another "real time database".  The short answer is you can't.  Firebase, Realm, and others can do what they do because they are in charge of every aspect of the database. The Datasync Community Toolkit starts with a premise that you want to own the data and use your own database.

That being said, there are things you CAN do to make it seem like you are using a real-time database.  However, you need to do a little bit of thinking. You need three things:

1. A real-time or near real-time communication channel between the server and the client.
2. A method of triggering an event that is transmitted on that communication channel.
3. A method of reacting to that event when it arrives are the client.

## Potential communication channels

There are a lot of options in the "potential communication channels" depending on your specific circumstances.

* You can use a concurrent real-time communication channel such as [WebSockets] or [SignalR].  Azure has scalable infrastructure for these that can scale up to about a million concurrent connections (if you have the money to support it).  However, the reality is that concurrent communication channels are expensive and more suited to smaller numbers of connections.
* You can use a two-way communication channel like [gRPC].  I've never used gRPC, but the two-way communication is how (for example) Firebase implements its real-time functionality.
* You can batch up the updates within a database, then use a long-polling HTTP request to get the updates.  This is highly scalable at the cost of more database tables to manage on the service.
* You can use an out-of-band communication channel like [APNS], [FCM], or [WNS] - let's face it, you are dealing with offline data, so this makes sense!

For this project, I'm going to use SignalR.  It's well supported by ASP.NET Core and scalable when combined with additional Azure services.

## Triggering an event from the datasync service

There are two ways of triggering an event on the datasync service:

1. You can hook into the `RepositoryUpdated` event on the table controller.
2. You can use the `PostCommitHookAsync` on the access control provider.

Which one should you use?  Well, it depends.  If you have decided that every single table controller will get its own access control provider that you will inject into the table using dependency injection, the `PostCommitHookAsync` is a great way to do this.  If, however, you (like me) prefer more separation of concerns, the event handler is the way to go.  There is no "one size fits all" here.  It's your code.

## Reacting to events on the client

How you react to events on the client depends on the communication channel.  I'm going to be sending an event over the communication channel that looks like this:

```json
{
  "action": "ADD",
  "type": "TodoItem",
  "data": {
    "id": "1234",
    "createdAt": "2024-12-24T03:00:00.123Z",
    "updatedAt": "2024-12-24T03:00:00.123Z",
    "version": "AAAAAAAB=",
    "title": "Santa Claus is coming!",
    "completed": false
  }
}
```

This data structure is expandable.  When I receive one of these messages, I can "do the right thing" on the client.  In my case, I'm going to create the SignalR channel with the `@microsoft/signalr` package, then wait for messages.  As each message is received, I'm going to add, delete, or update the data within my internal list.

## Walking through the code

I'm going to use a [base project][todoapp-start] for this.  I introduced this earlier - it's got a TodoMVC front end and an ASP.NET Core backend with the Datasync Community Toolkit already integrated.  I'll also show you how to do the trigger both ways.

Let's start by integrating the SignalR hub (that's the ASP.NET Core bit) into this project.

Next, let's adjust the client code so that it is receiving messages from the SignalR hub.

You should be able to run the application at this point.  Find your developer tools and look at the JavaScript console.  You should see that the SignalR connection is established and awaiting messages:

![An image showing the browser console window with logs](/assets/images/2024/11/2024-11-18-image1.png)

## Trigger an event via the access control provider

I introduced the `IAccessControlProvider` and access control [last time]({% post_url 2024/11/2024-11-12-datasync-part4 %}).  At the time, I said "PostCommitHookAsync is for eventing" and left it at that.  So, let's take a look at a sample access control provider that implements eventing:

```csharp
public class EventingProvider<T> : AccessControlProvider<T>
{

}
```

You can hook the access control provider up using dependency injection.  Here is the relevant line in the `Program.cs`:

```csharp
builder.Services.AddScoped<IAccessControlProvider<TodoItem>, EventingProvider<TodoItem>>();
```

And here is the replacement `TableController`:

```csharp
[Route("tables/[controller]")]
public class TodoItemsController : TableController<TodoItem>
{
  public TodoItemsController(AppDbContext context, IAccessControlProvider<TodoItem> acp) : base()
  {
    Repository = new EntityTableRepository<TodoItem>(context);
    AccessControlProvider = acp;
  }
}
```

Now, run the application and open two browser windows side by side.  It's best if you open up developer tools along the bottom for screen real-estate.  When you make changes to one of the browsers, those same changes are replicated on the other browser.

## Trigger an even using eventing

The table controller also has eventing built in, expliciting a `RepositoryUpdated` event.  This is a great way to hook in (for example) cross-site replication or to do other interesting things that you don't want to be doing in the main flow of the request.  This makes it a great option for triggering our event.  It only requires changes to the table controller:

```csharp
[Route("tables/[controller]")]
public class TodoItemsController : TableController<TodoItem>
{
  public TodoItemsController(AppDbContext context, IRealtimeService service) : base()
  {
    Repository = new EntityTableRepository<TodoItem>(context);
    RepositoryUpdated += async (RepositoryUpdatedEventArgs e) => {
      await service.SendUpdateAsync<TodoItem>(e.Operation.ToString(), e.Entity);
    };
  }
}
```

<!-- Links -->
[todoapp-start]: https://github.com/adrianhall/samples/blah-de-blah
[TodoMVC]: https://todomvc.com
[WebSockets]: https://something
[SignalR]: https://something
[gRPC]: https://something
[APNS]: https://something
[FCM]: https://something
[WNS]: https://something
