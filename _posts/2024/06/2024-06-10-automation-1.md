---
title:  "Social Media Automation: An introduction"
date:   2024-06-10
categories: automation
tags: [ bicep, azd, azure, functions, cosmosdb ]
header:
  image: "/assets/images/2024/06/2024-06-10-banner.png"
---

In my last series, I built this blog, including all the infrastructure and automated posting.  However, a lot of the social media posting is done by hand.  Yes, there are social media calendars like [Hootsuite](https://www.hootsuite.com/) and [Buffer](https://buffer.com/) that allow me to schedule posts for some of the social media networks, but I still have to write and schedule each post individually. Aside from that, these platforms inevitably cost more than the blog to run.  Hootsuite, for example, costs $99/month (or about 10 times the cost of the blog itself).  Obviously, these services can do a lot for me.  I am sure they are very valuable to businesses that have brands to protect. However, I am unlikely to use the majority of their functionality.

Fortunately, I'm a developer. I'm fairly sure I can develop a system that will do the work for me without the hassle of having to actually schedule anything.  Here is the way I am thinking of it from a systems point of view.

1. I'll have a piece of code that runs on a regular basis and pulls in anything that has been recently posted.  For each one, it will grab some metadata (more on this later) and store it into a data store.
2. Each morning when a post is due to go out, another piece of code will pull an appropriate record in the data store, extract the meta data for the social media network, then post it to the social media network.

This is about as straight forward as it gets.  However, let's go into detail.  The metadata that I am storing in the database will include:

* The post title.
* The post date.
* The post URL.
* Anything required by each social media platform.
  * For example, when posting to Reddit, I need to include a "sub-reddit" to post to.
* A short abstract or synopsis.

The post URL, title, and date are readily available from the markdown file that I use to write each post. Each post has "front matter" that looks something like this:

{% highlight yaml %}{% raw %}
---
title:  "Social Media Automation: An introduction"
date:   2024-06-10
categories: automation
tags: [ bicep, azd, azure, functions, cosmosdb ]
header:
  image: "/assets/images/2024/06/2024-06-10-banner.png"
---
{% endraw %}{% endhighlight %}

This is actually the front matter from this post. I'm going to augment the "front matter" data with the social media networks items as required.  That leaves the short abstract or synopsis.  Perhaps I can use an AI model to generate that for me.

Here is what my process architecture looks like:

![The process architecture for posting to social media networks](/assets/images/2024/06/2024-06-10-architecture.png)

There are a few components that I need to work out here.

## The data store

There are a bunch of "platform as a service" options for a data store on Azure, summarized here:

|-------------|--------------------|
| Service     | Minimum Cost       |
|-------------|--------------------|
| Azure SQL   | Free               |
| Cosmos DB   | Free               |
| MySQL       | $7/month           |
| PostgreSQL  | $14/month          |
| Redis Cache | $16/month          |

* All prices are for resources located in the "centralus" region at time of writing and does not include data transfer fees.
* See the [pricing page](https://azure.microsoft.com/pricing/) for current pricing and regions.

My data needs are best handled by a NoSQL database.  I don't need data normalization and my query capabilities don't cross tables.  I think the most complex query is going to be "give me a list of all articles that have not been posted to social media yet."  So I'm going to go with a free-tier Cosmos DB for my data store.  I could also normalize my data, in which case the Azure SQL database would also fit.  I'd also lean towards Azure SQL if I were coding things up in C# with Entity Framework Core.  While EF Core supports CosmosDB, it just works better with a SQL service.

Cosmos DB also [provides different APIs for accessing data](https://learn.microsoft.com/azure/cosmos-db/choose-api). You can use the NoSQL query dialect (which is the default), or you can choose from MongoDB, Cassandra, Apache Gremlin, Table storage, or PostgreSQL emulation.  These facets still use the same NoSQL store underneath but emulate the requirements of the access protocol, allowing you to use the default SDK for accessing that database.  Since I'm not integrating Cosmos DB with a third party library, I'm going to use the regular NoSQL dialect.

## Data ingest

My first task is to write a piece of code that connects to my site on a regular basis, pulls the `feed.xml` file, and creates entries in the data store.  I'm also going to use this same piece of code to generate an excerpt that I can use for social media posting at the same time.  Again, there are various mechanisms that I can use for this:

* [Azure Logic Apps](https://learn.microsoft.com/azure/logic-apps/logic-apps-overview)
* [Azure Functions](https://learn.microsoft.com/azure/azure-functions/)
* [Azure Durable Functions](https://learn.microsoft.com/azure/azure-functions/durable/)
* [Power Automate](https://make.powerautomate.com/)

I can also use external services like [IFTTT](https://ifttt.com/) for this sort of functionality.  However, I want to ensure that I have repeatable deployments; that I get complete control over the code that is running; and that I can run the code locally for debugging.  That leaves me with Azure Functions and Azure Durable Functions.  Durable functions are more for workflow and fan-in/fan-out type functionality, so it's not really appropriate for my situation.  I'm going with Azure Functions for my data ingest.

In case you are wondering, the pricing on my Azure Functions usage is likely to also be free.  Azure Functions provides 1 million executions for free per month.

> **Managed functions in Azure Static Web Apps?**<br/>
> You can host Azure Functions inside Azure Static Web Apps.  This is for handling API endpoints, and it's useful when you need your API endpoints to be deployed at the same time as your web site.  My feed is hosted on Azure Static Web Apps so it's only natural that I would take a look at this option.  I decided to create a separate service for this

## AI Services

One of the main advantages of using a major cloud like Azure is the sheer quantity of things you can do with little to no code in the realm of AI.  I'll be the first to admit that I do not understand how AI works.  Thus, it is hard for me to generate my own model for doing even the most basic of tasks.  But that shouldn't stop me from taking advantage of pre-built models that the cloud provides.  In this case, I'm going to take advantage of the summarization API built into the [Azure AI Language service](https://learn.microsoft.com/azure/ai-services/language-service/overview).  There is even a guide showing how to do document summarization within the documentation.

The Azure AI Language service is the gateway drug to "true AI processing", so it's no surprise that there is a free tier.  The Azure AI Language service is free for up to 5,000 text records.  Given my minimal usage, I believe my usage of this service will also be free.

## Posting to social media networks

The last part of my architecture involves posting to social media networks.  Since I am already using Azure Functions, I'm going to also use Azure Functions for this bit of the project.  This will involve a piece of code that basically wraps the functionality:

* Select the post to publish from the data store based on:
    1. If there is one or more unpublished posts for this social media network, select the oldest one.
    2. If there isn't an unpublished post, select the one that hasn't been published recently (oldest date of publication)
* Construct the appropriate API call and publish to the social media network.
* Update the data store record to set the date of last publication.

I can then repeat this for each social media network.  Then I can select the appropriate posting schedule and away they go!

## Anything else?

Since this is an automated system, I have to consider two items:

* How can I track a post through the system?
* How will I know when something goes wrong and what to do about it?

Fortunately, both of these are handled by judicious logging.  I'll set up [Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/) for this and link every component of this architecture into Application Insights so that I can track and monitor the system.

Finally, I want to be aware of intra-system authentication and security.  Passwords in cloud environments are bad, so I want to make sure I leverage managed identities for authenticating my services and role-based authorization to ensure that each managed identity is restricted to only work on what is required.

## Final thoughts

It's always a good idea to sit down and think about what you want to do before you put fingers to keyboard.  By breaking down the problem (which, let's face it, isn't that difficult a problem) into the component parts and considering each one individually, I can focus on what is important at each step, while ensuring each one can be tested individually.

## Further reading

* [Azure Cosmos DB - Developer Community](https://developer.azurecosmosdb.com/community)
* [Azure Cosmos DB - Documentation](https://learn.microsoft.com/azure/cosmos-db/)
* [Azure Functions](https://learn.microsoft.com/azure/azure-functions/)
* [Azure AI Language](https://learn.microsoft.com/azure/ai-services/language-service/overview)
* [Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/)
