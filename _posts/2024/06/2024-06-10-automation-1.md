---
title:  "Social Media Automation: The infrastructure"
date:   2024-06-11
categories: automation
tags: [ bicep, azd, azure, functions, cosmosdb ]
header:
  image: "/assets/images/2024/06/2024-06-10-banner.png"
---

In my last series, I built this blog, including all the infrastructure and automated posting.  However, a lot of the social media posting is done by hand.  Yes, there are social media calendars like [Hootsuite](https://www.hootsuite.com/) and [Buffer](https://buffer.com/) that allow me to schedule posts for some of the social media networks, but I still have to write and schedule each post individually. Aside from that, these platforms inevitably cost more than the blog to run.  Hootsuite, for example, costs $99/month (or about 10 times the cost of the blog itself).  Obviously, these services can do a lot for me.  I am sure they are very valuable to businesses that have brands to protect. However, I am unlikely to use the majority of their functionality.

Fortunately, I'm a developer. I'm fairly sure I can develop a system that will do the work for me without the hassle of having to actually schedule anything.  From a systems point of view, it's fairly easy.  I'll have a piece of code that runs on a regular basis to read the feed (which is generated via the Jekyll publishing process) and then create a record per post in a tracking data store.  Then I'll have another piece of code that runs on my posting schedule that selects a post to publish from the tracking data store and does the publishing.

## Azure resources

There are a lot of ways to create this application, but I'm looking to reduce the cost of the system.  I think I can get it close to "free" for my small requirements.  [Cosmos DB](https://learn.microsoft.com/azure/cosmos-db/) has a "free forever" tier, so that gives me a solid NoSQL database to act as the tracking data store.  Azure Functions is a serverless mechanism for running small pieces of code that can execute in under five minutes.  You get a million executions a month for free, which is plenty.  Even if you had to pay for Cosmos DB and Azure Functions because you were over the free tier limits, the amounts are small.

One additional extra I want to be concerned about is managed identities.  Basically, my Azure Functions are going to have to authenticate to Cosmos DB to read and write data.  I don't want to implement passwords here.  Passwords for services are bad, since - however unlikely - "stuff happens" and the secret gets leaked.  This results in a requirement to rotate the secrets on a regular basis which is way more frequent than I'm comfortable with.  The best secret is no secret and managed identities allow me to secure and authenticate the communication between the Azure Functions and the Cosmos DB.

## Provisioning

I'm going to use the same mechanism for provisioning as my blog.  That means I'll be writing the provisioning code in [bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview) and integrating it into my existing [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/overview) setup.  I'll use [Azure Verified Modules](https://aka.ms/AVM) for creating the resources.   I've re-organized my bicep code a little to keep the Jekyll site stuff separate from the social media automation stuff.  Deployment modules are great for this.

I'm not going to go over the over 200 lines of bicep code in this post.  The provisioning code is relatively straight forward and I'm not doing anything special for most of it.  You can [find the code on my GitHub repository](https://github.com/adrianhall/apps-on-azure-blog/blob/main/infra/app/social-media.bicep).  However, there is one notable piece.  At the end of the module, I add the following:

{% highlight bicep %}
module cosmosRoleAssignment '../modules/cosmos-role-assignment.bicep' = {
  name: 'm-sma-cosmos-role-${resourceToken}'
  params: {
    cosmosAccountName: cosmosAccount.name
    principalId: functionApp.identity.principalId
  }
}
{% endhighlight %}

I've set up the function app with a system-assigned managed identity.  That managed identity doesn't have access to anything by default.  I need to give the managed identity permissions.  The module that is being called gives the provided managed identity permission to read and write any container in any database connected to the provided Cosmos DB account.  That happens with the following code:

{% highlight bicep %}
@description('The name of the Cosmos DB account that we will use for SQL Role Assignments')
param cosmosAccountName string

@description('The Principal Id that we will grant the role assignment to.')
param principalId string

var roleDefinitionId = guid('sql-role-definition-', principalId, account.id)
var roleAssignmentId = guid(roleDefinitionId, principalId, account.id)

resource account 'Microsoft.DocumentDB/databaseAccounts@2021-11-15-preview' existing = {
  name: cosmosAccountName
}

resource sqlRoleDefinition 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2021-11-15-preview' = {
  parent: account
  name: roleDefinitionId
  properties: {
    roleName: 'Read and Write all containers'
    type: 'CustomRole'
    assignableScopes: [ account.id ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*'
        ]
      }
    ]
  }
}

resource sqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-11-15-preview' = {
  parent: account
  name: roleAssignmentId
  properties: {
    roleDefinitionId: sqlRoleDefinition.id
    principalId: principalId
    scope: account.id
  }
}
{% endhighlight %}

First, I create a role within the Cosmos DB account that defines a custom role for this managed identity.  In this case, I'm defining it to allow reading and writing of all data, but it can't, for example, create a new container or mess with permissions.  Then I assign the managed identity to that role.  When the function app connects to this Cosmos DB account, it will do so with the managed identity that I've defined and thus will have the correct permissions - all without passwords.

## Final thoughts

It's always a good idea to sit down and think about what you want to do before you put fingers to keyboard.  By breaking down the problem (which, let's face it, isn't that difficult a problem) into the component parts and considering each one individually, I can focus on what is important at each step, while ensuring each one can be tested individually.

In my next post, I'm going to write an Azure Function that will read from my feed and populate the database.  Until then, happy hacking!

## Further reading

* [Azure Cosmos DB - Developer Community](https://developer.azurecosmosdb.com/community)
* [Azure Cosmos DB - Documentation](https://learn.microsoft.com/azure/cosmos-db/)
* [Azure Functions](https://learn.microsoft.com/azure/azure-functions/)
* [Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/)
* [Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview)
* [Azure Verified Modules](https://aka.ms/AVM)
