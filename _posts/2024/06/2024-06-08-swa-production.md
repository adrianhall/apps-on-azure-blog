---
title:  "Build a Blog: Going to production with Azure Static Web Apps"
date:   2024-06-08
categories: infrastructure
tags: [ bicep, azd, azure, staticwebapps ]
header:
  image: "/assets/images/2024/06/2024-06-08-banner.png"
---

I'm almost ready to take my blog to production and make it public.  However, there are a few things that I want to make sure I do before going to production.  This is true of any application hosted in the cloud, so it;s a good reminder of things to think about.

<!-- more -->

This post is part of a sequence showing how to deploy a blog on Azure Static Web Apps:

1. [Deploying Azure Static Web Apps]({% post_url 2024/06/2024-06-05-swa-deploy %})
2. [Configuring Azure DNS]({% post_url 2024/06/2024-06-06-azure-dns %})
3. [Configuring Static Web Apps Custom Domains]({% post_url 2024/06/2024-06-07-swa-dns %})
4. [Taking Static Web Apps to Production]({% post_url 2024/06/2024-06-08-swa-production %})

So, what are these things?  Here is my list:

* Check the SKU of the resources to make sure they are suitable for production usage.
* Switch the default domain to my custom domain.
* Establish resource locks so I don't accidentally delete the site.
* Create a budget so my costs don't balloon without my knowing about it.

I also need to do all the things my site requires; things like setting up Google Analytics, webmaster site verifications, setting up the comments system, and so on.  Basically, whatever demands your site has beyond infrastructure still need to be done.  Finally, I would want to consider some of the other Azure offerings like [Defender for Cloud](https://azure.microsoft.com/products/defender-for-cloud/) if I were an enterprise.  I'm not, so I'm going to bypass those considerations.

> **What about logging?**
> Static sites are heavily cached and use site analytics capabilities like [Google Analytics](https://analytics.google.com/) or [Microsoft Clarity](https://clarity.microsoft.com/) for web site logging.  It's integrated into the application instead of the system.  Azure Static Web Apps does provide some diagnostics within the Azure Portal, but it's not required due to the caching.

## Check the SKU

So far, my site has been running on the "Free" SKU for Static Web Apps.  This has been great while I've been starting and has offered me everything I need.  Do I need something bigger:

* Free SKU has a limit of 100Gb of bandwidth.  The Standard SKU includes 100Gb of bandwidth, but allows you to go higher on a monthly basis.
* Free SKU supports 2 domains.  Standard SKU supports 5 domains.
* Standard SKU supports custom authentication, which is unsupported in Free SKU.
* Standard SKU supports larger storage capacity.
* Standard SKU has an SLA.

In short, I want to spend the $9/month for a Standard SKU for a production site.  I've adjusted this in my `infra/main.bicep` file (as we'll see at the end).

## Set the default custom domain

Some things are easier to do on the Azure portal.  I now have three domains:

![Screenshot of the registered custom domains](/assets/images/2024/06/2024-06-08-customdomains.png)

I have not set a default yet, so the auto-generated domain is the default.  While this doesn't affect the functioning of the site, I don't want the auto-generated domain to leak out.  Other users of my site may want to bookmark specific pages.  If I have to re-create the site, that auto-generated domain will change and those bookmarks will be broken.

I want to make `apps-on-azure.net` the default domain, so I need to highlight it and click on **Set default**.  

## Create resource locks

While I am at it, I'm also going to establish resource locks on my critical resources so I don't accidentally delete them.  Let's put all this together and take a look at the `infra\main.bicep` changes:

{% highlight bicep %}
var lock = { kind: 'CanNotDelete' }

module swa 'br/public:avm/res/web/static-site:0.3.0' = {
  name: 'swa-${resourceToken}'
  scope: rg
  params: {
    name: '${environmentName}-web-${resourceToken}'
    location: location
    lock: lock
    sku: 'Standard'
    tags: union(tags, { 'azd-service-name': 'web' })
  }
}

module dnszone 'br/public:avm/res/network/dns-zone:0.3.0' = {
  name: 'dnszone-${resourceToken}'
  scope: rg
  params: {
    name: zoneName
    location: 'global'
    lock: lock
    tags: tags
  }
}
{% endhighlight %}

This only includes the changes (but you can see the entire file [on my GitHub repository](https://github.com/adrianhall/apps-on-azure-blog/blob/main/infra/main.bicep)).  The "lock" variable definition is a standard thing across all Azure Verified Modules so I can reuse it.  In the `swa` module, I've added the lock and updated the SKU.  In the `dnszone` module, I've just added the lock.

## Create a budget

Let's think about the budget here.  My static web site is $9/month, and my DNS zone is approximately $1/month.  This gives me a total of $10/month.  I don't want to be alerted before this, but I do want to be alerted if the usage goes awry and I get much higher than that.  I'm going to set up a budget resource for all the resources within the resource group and set up some alerts.  I can also do this in bicep.  Here is the module definition:

{% highlight bicep %}
module budget 'br/public:avm/res/consumption/budget:0.3.3' = {
  name: 'budget-${resourceToken}'
  params: {
    amount: 10
    name: 'apps-on-azure-budget-${resourceToken}'
    contactEmails: [
      'photoadrian@outlook.com'
    ]
    location: location

    category: 'Cost'
    resourceGroupFilter: [ rg.name ]
    resetPeriod: 'BillingMonth'
    thresholds: [ 100, 125, 150, 200 ]
  }
}
{% endhighlight %}

My bicep file is relatively small.  Putting the budget in the bicep file gives me a prod to ensure that I update the budget if I add or remove resources.

## Final thoughts

I am guilty of a major misconception.  I have assumed that things can happen quicker than they actually do. Building a static web app and deploying some code to it takes less than fifteen minutes. Going to production, with all the nuances that causes, took four days. Some of that was because I was in meetings or adjusting code for the production environment. Some of that was waiting around for things to happen - like setting up DNS. Finally, some of that was simply reading documentation about features I had not used before, then sitting back and thinking if I should use them. Building production systems takes way longer than producing a demo (which is my normal mode).

There are other "production ready" references in the Azure world.  Two that come to mind:

* [Landing zone accelerators](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/app-platform/ready)
* [Reliable Web App Pattern](https://learn.microsoft.com/azure/architecture/web-apps/guides/reliable-web-app/overview)

These are more extensive than what I am doing and take into account the security, resiliency, and operational requirements of enterprises - none of which was a concern for my site.

## Further reading

* [Azure Verified Modules](https://aka.ms/AVM)
* [Azure Cost Management](https://learn.microsoft.com/azure/cost-management-billing/costs/overview-cost-management)
* [Microsoft Clarity](https://clarity.microsoft.com)
* [Google Analytics](https://analytics.google.com)
