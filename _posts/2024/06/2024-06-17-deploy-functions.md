---
title:  "Social Media Automation: Deploy Azure Functions with AZD"
date:   2024-06-17
categories: automation
tags: [ bicep, azd, azure, functions, cosmosdb ]
header:
  image: "/assets/images/2024/06/2024-06-17-banner.png"
---

Today, I'm continuing on my theme of automating my social media posting.  I've got the [basic project infrastructure set up]({% post_url 2024/06/2024-06-11-automation-1 %}) and I've got [Jekyll to produce a JSONFeed file of all the recent posts]({% post_url 2024/06/2024-06-14-jekyll-json %}).  Next up, I need to put in some automation to read the JSONFeed file on a regular basis and then write the new posts to my Cosmos DB container.  To help along with this, I've defined some environment variables in my Azure Function App:

```bicep
        {
          name: 'DatabaseName'
          value: cosmosDatabase.name
        }
        {
          name: 'ContainerName'
          value: cosmosContainer.name
        }
        {
          name: 'CosmosDbEndpoint'
          value: cosmosAccount.properties.documentEndpoint
        }
```

Let's start by creating a basic Azure Function environment and running it.  The [func command](https://learn.microsoft.com/azure/azure-functions/functions-run-local), which can be installed on your dev box, can create an appropriate environment.  I ran `func init social-media-automation` from my root directory, answered a few questions, and that created my environment for me. If you are looking at the [blog repository](https://github.com/adrianhall/apps-on-azure-blog), then you'll see the `social-media-automation` folder with all the files.

![The files created by func init command](/assets/images/20204/06/2024-06-17-image1.png)

Change into the `social-media-automation` directory in your terminal to run the rest of the command line tools.  The first tool is to list the templates: `func templates list`.  You'll notice there are a lot of tools.  Each one is just a template - you can also create the functions without the templates.  I'm going to create a function based on the `Timer trigger` template:

```bash
func new --template "Timer trigger" --name ReadJsonFeedFromBlog
```

This creates the `ReadJsonFeedFromBlog.js` file in the `src/functions` directory:

```javascript
const { app } = require('@azure/functions');

app.timer('ReadJsonFeedFromBlog', {
    schedule: '0 */5 * * * *',
    handler: (myTimer, context) => {
        context.log('Timer function processed request.');
    }
});
```

## Running the function locally

My first stop is to ensure I can run the function locally and see the output.  One of the easiest ways to do this is to use Visual Studio Code with the [Azure Functions extension]().  Open the `social-media-automation` folder in Visual Studio Code, go to the `Azure` section of the side bar, and expand the *Workspace* section.  This will allow you to right-click the function you have created and run it manually.  You can also set break points in your code and debug the function code just like you would any other Node application.  In fact, this is my preferred way of doing things when I am developing code.

However, sometimes I need to run things manually.  How do we do that?  

First off, Azure Functions requires Azure Storage, even when running locally.  You can use either the [Azure Storage Emulator](https://learn.microsoft.comazure/storage/common/storage-use-emulator#get-the-storage-emulator) or [Azurite](https://github.com/azure/azurite?tab=readme-ov-file#getting-started).  I prefer Azurite since it is cross-platform whereas Azure Storage Emulator supports Windows only. To install and run Azurite in your project:

```bash
npm install -D azurite
npx azurite -s -l C:\Azurite -d C:\Azurite\debug.log
```

Adjust for your environment (Linux or Mac), obviously.

> Azurite can also be installed as [a Visual Studio Code extension](https://marketplace.visualstudio.com/items?itemName=Azurite.azurite) and can be run in a way that doesn't require an additional terminal.

Next, you need to start the functions runtime.  You can run `npm start` or `func start` for this.  

```bash
func start
```

This command will seem to hang if the storage emulator is not running.  If you run (as suggested) with the `--verbose` flag, you will see errors in the console indicating that the functions host could not reach `http://127.0.0.1:10000`.  This is an indication that the storage emulator is not running.

You will notice a set of logs indicating the cron schedule established is going to work:

```text
[2024-06-17T19:09:45.723Z] The next 5 occurrences of the 'ReadJsonFeedFromBlog' schedule (Cron: '0 0,5,10,15,20,25,30,35,40,45,50,55 * * * *') will be:
[2024-06-17T19:09:45.724Z] 06/17/2024 12:10:00-07:00 (06/17/2024 19:10:00Z)
[2024-06-17T19:09:45.726Z] 06/17/2024 12:15:00-07:00 (06/17/2024 19:15:00Z)
[2024-06-17T19:09:45.727Z] 06/17/2024 12:20:00-07:00 (06/17/2024 19:20:00Z)
[2024-06-17T19:09:45.728Z] 06/17/2024 12:25:00-07:00 (06/17/2024 19:25:00Z)
[2024-06-17T19:09:45.730Z] 06/17/2024 12:30:00-07:00 (06/17/2024 19:30:00Z)
```

Press CTRL-C to terminate the function runtime.

There are two things I need to do here.  Firstly, I need to trigger the function at will.  Having it on a cron job is good, but my final code is only going to be running once a day and not on a schedule that is convenient to my working hours.  The first thing I did was to turn down the frequency of the function:

```javascript
const { app } = require('@azure/functions');

app.timer('ReadJsonFeedFromBlog', {
    schedule: '12 3 * * * *',
    handler: (myTimer, context) => {
        context.log('Timer function processed request.');
    }
});
```

The `schedule` field is a standard [crontab](https://learn.microsoft.com/azure/azure-functions/functions-bindings-timer?pivots=programming-language-javascript#ncrontab-expressions) statement.  The new statement runs at 3:12am every morning, which is much more appropriate to my proposed functionality.  Next, I need to trigger the run myself.  To do that, I need to send a POST command to `http://localhost:7071/admin/ReadJsonFeedFromBlog`. There are a multitude of methods for doing this.  Perhaps the easiest is to use cURL:

```bash
curl --request -POST -H "Content-Type:application/json" --data "{'input':''}" http://localhost:7071/admin/ReadJsonFeedFromBlog
```


