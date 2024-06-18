---
title:  "Social Media Automation: Develop and deploy Azure Functions with AZD"
date:   2024-06-17
categories: automation
tags: [ bicep, azd, azure, functions, cosmosdb ]
header:
  image: "/assets/images/2024/06/2024-06-17-banner.png"
  teaser: "/assets/images/2024/06/2024-06-17-banner.png"
---

Today, I'm continuing on my theme of automating my social media posting.  I've got the [basic project infrastructure set up]({% post_url 2024/06/2024-06-11-automation-1 %}) and I've got [Jekyll to produce a JSONFeed file of all the recent posts]({% post_url 2024/06/2024-06-14-jekyll-json %}).  Next up, I need to put in some automation to read the JSONFeed file on a regular basis and then write the new posts to my Cosmos DB container.

Let's start by creating a basic Azure Function environment and running it.  The [func command](https://learn.microsoft.com/azure/azure-functions/functions-run-local), which can be installed on your dev box, can create an appropriate environment.  I ran `func init social-media-automation` from my root directory, answered a few questions, and that created my environment for me. If you are looking at the [blog repository](https://github.com/adrianhall/apps-on-azure-blog), then you'll see the `social-media-automation` folder with all the files.

![The files created by func init command](/assets/images/2024/06/2024-06-17-image1.png)

Change into the `social-media-automation` directory in your terminal to run the rest of the command line tools.  The first tool is to list the templates: `func templates list`.  You'll notice there are a lot of templates.  You'll find a list of all the supported triggers in [the Azure Functions documentation](https://learn.microsoft.com/azure/azure-functions/) under the reference section.  You don't need a template to create a function - it's just a simple starting point. I'm going to create a function based on the `Timer trigger` template:

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

## Develop the function locally

My first stop is to ensure I can run the function locally and see the output.  One of the easiest ways to do this is to use [Visual Studio Code](https://learn.microsoft.com/en-us/azure/azure-functions/functions-develop-vs-code?tabs=node-v4%2Cpython-v2%2Cisolated-process&pivots=programming-language-javascript) with the [Azure Functions extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions).  It takes a little bit of setup, but ends up being a good way to run functions locally for debugging purposes.

However, sometimes I need to run things manually.  How do I do that?  

Azure Functions requires Azure Storage, even when running locally.  You can use either the [Azure Storage Emulator](https://learn.microsoft.comazure/storage/common/storage-use-emulator#get-the-storage-emulator) or [Azurite](https://github.com/azure/azurite?tab=readme-ov-file#getting-started) to emulate this functionality locally.  I prefer Azurite since it is cross-platform whereas Azure Storage Emulator supports Windows only. To install and run Azurite in your project:

```bash
npm install -D azurite
npx azurite -s -l C:\Azurite -d C:\Azurite\debug.log
```

The location doesn't need to exist as long as you can write to the parent directory.  

> Azurite can also be installed as [a Visual Studio Code extension](https://marketplace.visualstudio.com/items?itemName=Azurite.azurite) and can be run in a way that doesn't require an additional terminal.

Next, start the functions runtime.  Open up a new terminal window, change directory to the functions project directory, then run the following command:

```bash
func start --verbose
```

This command will seem to hang if the storage emulator is not running.  If you run (as suggested) with the `--verbose` flag, you will see errors in the console indicating that the functions host could not reach `http://127.0.0.1:10000`.  This is an indication that the storage emulator is not running.  Eventually, the following is printed indicating the cron schedule has been established:

```text
[2024-06-17T19:09:45.723Z] The next 5 occurrences of the 'ReadJsonFeedFromBlog' schedule (Cron: '0 0,5,10,15,20,25,30,35,40,45,50,55 * * * *') will be:
[2024-06-17T19:09:45.724Z] 06/17/2024 12:10:00-07:00 (06/17/2024 19:10:00Z)
[2024-06-17T19:09:45.726Z] 06/17/2024 12:15:00-07:00 (06/17/2024 19:15:00Z)
[2024-06-17T19:09:45.727Z] 06/17/2024 12:20:00-07:00 (06/17/2024 19:20:00Z)
[2024-06-17T19:09:45.728Z] 06/17/2024 12:25:00-07:00 (06/17/2024 19:25:00Z)
[2024-06-17T19:09:45.730Z] 06/17/2024 12:30:00-07:00 (06/17/2024 19:30:00Z)
```

The function runtime will reload your functions whenever they change.  So I can now edit the code file(s) making up the function and then immediately swap over to another new terminal to run the function.

So, how do I run the function?  There is a method of triggering a non-HTTP function manually.  However, experimentation indicates that timer triggers cannot be triggered manually (at time of writing).  An alternative is to turn the code into a HTTP trigger while you are working on it, then turn it back into a timer trigger afterwards.  For example:

```javascript
const { app } = require('@azure/functions');

app.http('ReadJsonFeedFromBlog', {
  methods: [ 'GET' ],
  authLelel: 'anonymous',
  handler: async (request, context) => {
    context.info('LOG>>> HTTP function "ReadJsonFeedFromBlog" processed request.');
    return { body: `Hello!` };
  }
});
```

I like using HTTP triggers since it allows me to return relevant information back to the developer (me) without having to watch the logs for that same information.  Of course, having a great debugging environment where I can set break points and run the code manually is also good.  Visual Studio Code supplies that capability.  However, it's not required.

I can trigger this function using the URL:

```bash
curl http://localhost:7071/api/ReadJsonFeedFromBlog
Hello!
```

The "Hello!" comes from the backend.  In the verbose logs for the functions runtime, I can see the following:

```text
[2024-06-18T15:47:51.463Z] Executing HTTP request: {
[2024-06-18T15:47:51.465Z]   "requestId": "2dd7ad61-a7fd-4b91-918d-bb23ee8d377e",
[2024-06-18T15:47:51.466Z]   "method": "GET",
[2024-06-18T15:47:51.468Z]   "userAgent": "curl/8.7.1",
[2024-06-18T15:47:51.469Z]   "uri": "/api/ReadJsonFeedFromBlog"
[2024-06-18T15:47:51.471Z] }
[2024-06-18T15:47:51.526Z] Executing 'Functions.ReadJsonFeedFromBlog' (Reason='This function was programmatically called via the host APIs.', Id=0c7c6380-701f-4b9e-a7ea-8e838920e3a0)
[2024-06-18T15:47:51.585Z] Worker 94806bc8-d7fb-4704-a75e-647e183601b3 received FunctionInvocationRequest with invocationId 0c7c6380-701f-4b9e-a7ea-8e838920e3a0
[2024-06-18T15:47:51.593Z] LOG>>> HTTP function "ReadJsonFeedFromBlog" processed request.
[2024-06-18T15:47:51.666Z] Executed 'Functions.ReadJsonFeedFromBlog' (Succeeded, Id=0c7c6380-701f-4b9e-a7ea-8e838920e3a0, Duration=160ms)
[2024-06-18T15:47:51.689Z] Executed HTTP request: {
[2024-06-18T15:47:51.690Z]   "requestId": "2dd7ad61-a7fd-4b91-918d-bb23ee8d377e",
[2024-06-18T15:47:51.692Z]   "identities": "",
[2024-06-18T15:47:51.693Z]   "status": "200",
[2024-06-18T15:47:51.694Z]   "duration": "225"
[2024-06-18T15:47:51.696Z] }
```

I can now finish off writing my code (which I won't go into here - this post is about developing and deploying functions).

### A helpful hint - API and Timer versions of the same code

One of the things I found useful was to have two versions of my code - one for when I am running locally (so I can trigger it using an API call) and one for when I am running in the cloud (so I can trigger it with a timer).  The functions runtime sets an environment variable 'FUNCTIONS_CORETOOLS_ENVIRONMENT' to 'true' when running locally.  This is not set at all when running in the cloud.  I can use this to set up the API version of the function when I am running locally:

```javascript
const { app } = require('@azure/functions');

const runningLocally = process.env.FUNCTIONS_CORETOOLS_ENVIRONMENT === "true";
const functionName = 'ReadJsonFeedFromBlog';
const schedule = '30 12 3 * * *';

function read_jsonfeed_from_blog(context) {
  context.verbose(`${functionName}>>> start: read_jsonfeed_from_blog`);

  context.verbose(`${functionName}>>> end: read_jsonfeed_from_blog`);
  return {};
}

if (runningLocally) {
  app.http(functionName, {
    methods: [ 'GET' ],
    authLevel: 'anonymous',
    handler: async (request, context) => {
      context.verbose(`LOG>>> HTTP function "${functionName}" started`);
      const output = read_jsonfeed_from_blog(context);
      context.verbose(`LOG>>> HTTP function "${functionName}" finished`);
      return { body: JSON.stringify(output) };
    }
  });
} else {
  app.timer(functionName, {
    schedule: '30 12 3 * * *',
    handler: (timerInput, context) => {
      context.verbose(`LOG>>> Timer function "${functionName}" started`);
      const output = read_jsonfeed_from_blog(context);
      context.verbose(`LOG>>> Timer function "${functionName}" finished`);
      return;
    }
  });
}
```

I have isolated "my code" in a separate function.  I then link the code into the appropriate type of trigger for the environment I am working in.

## Deploying the function to Azure

In the [first post of this series]({% post_url 2024/06/2024-06-11-automation-1 %}), I set up the bicep for deploying the infrastructure for this project.  In there, I assigned a tag 'azd-service-name'.  This allows me to associate the code that I need to deploy to the correct service.  All I need to do now is to add the appropriate entry into the `azure.yaml` file:

```yml
# yaml-language-server: $schema=https://raw.githubusercontent.com/Azure/azure-dev/main/schemas/v1.0/azure.yaml.json

name: apps-on-azure-blog
services:
  web:
    project: .
    dist: _site
    language: js
    host: staticwebapp
  social-media-automation:
    project: ./social-media-automation
    language: js
    host: function
```

I can now use `azd up` to deploy my social media automation system.  Since I've integrated azd with GitHub Actions, my system is also deployed when I merge into main.

## Final thoughts

I've covered two separate things in this post - developing Azure Functions locally and deploying Azure Functions.  Deploying Azure Functions to the cloud is super simple with the [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/overview) and allows me to go from local development to remote deployment with ease.  Developing functions is a little harder.  There is a focus on Visual Studio Code (and Visual Studio if you happen to be developing C# functions).  The programming model is different to what I'm used to (which is ok - it's not a bad thing) and the setup of the tooling is multi-step (which could be improved).  Overall, however, these things are small bumps in the road to productivity.

In the next post, I'm going to show off my function code and have a discussion about integrating AI to provide the social media post content for me.  Until then, happy hacking!

## Further reading

* [Develop and debug Azure Functions locally](https://learn.microsoft.com/azure/azure-functions/functions-develop-local)
* [Azure Functions: Timer trigger](https://learn.microsoft.com/azure/azure-functions/functions-bindings-timer?tabs=python-v2%2Cisolated-process%2Cnodejs-v4&pivots=programming-language-javascript)
* [Azure Functions: HTTP trigger](https://learn.microsoft.com/azure/azure-functions/functions-bindings-http-webhook-trigger?tabs=python-v2%2Cisolated-process%2Cnodejs-v4%2Cfunctionsv2&pivots=programming-language-javascript)
* [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/overview)
