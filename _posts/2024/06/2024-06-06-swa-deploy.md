---
title:  "Deploying Azure Infrastructure three ways"
date:   2024-06-06
categories: infrastructure
tags: [ bicep, azd, azure, staticwebapp ]
header:
  image: "/assets/images/2024/06/2024-06-06-teaser.png"
---

For most developers, dealing with the infrastructure part of the job is hard.  I like to say "give me a database and a web site" and prefer not to get into the other requirements.  My web sites and other cloud projects (including this one) are pretty open. So, what's the minimum I need to know to deploy stuff on Azure?

<!-- more -->

Today, I'm going to look at three ways to deploy the same thing.  That "thing" is an Azure Static Web App - the same one that is used to host this web site.  I'll look at the techniques and why it is better (or worse) than the others.

Three ways?  Surely, there are more than that!  Why, yes.  There are.  You can use any number of infrastructure as code (IaC) tools, and there are lots of opinions on how to lay out an infrastructure for enterprise use (which I promise to cover in later blog posts).  However, this is early days of the blog, so I don't need much.  It's time to "keep it simple".

When you are developing cloud code, you need to do THREE things to get your stuff on the cloud:

1. Provision the infrastructure.
2. Configure the infrastructure to accept your code.
3. Deploy your code to the infrastructure.

For the purposes of the walk-through today, I'm using the Jekyll site that I used to build this blog.  But you could use anything.

## The infrastructure

For my purposes (this blog site), I only need one resource - an [Azure Static Web App](https://learn.microsoft.com/azure/static-web-apps/overview).  A static web app is a resource that holds and serves the HTML, CSS, JavaScript, and other assets for a web site.  It can be any web site - React, Vue, Angular, Svelte, Solid, Qwik, Next, Nuxt, Nest, or any other HTML/JS web framework.  You don't even need a web framework.  Use a static site generator like Jekyll (used to generate this site), Hugo, Docusaurus, Hexo, Vuepress, and many more can be used.

You only need the ability to generate the HTML, CSS, JavaScript, and assets for the web site.

Once you've deployed your code, your site is globally available and cached at the edge.  You can use GitHub Actions to deploy your code automatically - it's a zero downtime deployment (i.e. the new site doesn't take over until all the files are in place for the new site).

Once you are ready to go to production, you can upgrade the SKU and add a custom domain without any down time.

There are other good things about Azure Static Web Apps (and we'll discover them as we go along).  For now, let's look at the three ways to get your code running in the cloud.

## Method 1: The CLIs

Some people like to have control, so this method gives you the ability to control exactly what is going on every step of the way.  So, let's take a look at what we need to do to provision, configure, and deploy this site.

### Prerequisites

You need a few tools.  If you took a look at [my last post]({% post_url 2024-06-04-devcontainers %}), you'll note I have all these tools in my dev container.  The links are to the installation page for the tool and don't include any tooling you need to build your application.

* [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
* [NodeJS](https://nodejs.org)

You will also want to [sign in to Azure](https://learn.microsoft.com/cli/azure/authenticate-azure-cli-interactively) and [select a subscription](https://learn.microsoft.com/cli/azure/manage-azure-subscriptions-azure-cli) if you have access to more than one subscription.

### Create the resources

All resources are created inside a [resource group](https://learn.microsoft.com/azure/azure-resource-manager/management/overview) - a container for related resources, so I have to create one of those first.

```bash
az group create -n apps-on-azure -l centralus
```

Now we can easily create a static web app resource:

```bash
az staticwebapp create -n apps-on-azure-site -g apps-on-azure -l centralus
```

> You can also use Azure PowerShell and the Azure Portal for these steps.

### Configure the resources

The main thing to do here is to configure a `staticwebapp.config.json` file.  This is sent to Azure Static Web Apps to configure the features needed.  I don't actually need anything beyond the basic hosting, so my file is remarkably simple:

```json
{
  "navigationFallback": {
    "rewrite": "/index.html"
  }
}
```

This tells Static Web Apps where the index page that I want to use is located.

### Deploy the code to the resources

To deploy the code, I'm going to use the [Static Web Apps CLI](https://azure.github.io/static-web-apps-cli).  This is one of those "npm" tools, so it's easy to install in the project:

```bash
npm add -D @azure/static-web-apps-cli
npx swa init --yes
```

The initialization tries to detect what is application is based on and thus where it can expect the output or distributable files.  My build process is `bundle exec jekyll build` and the files are placed in `_site` after the build.  Check out the output of the `swa init` command:

<!-- TODO: Screen shot of swa init output -->

Now I can deploy the code:

```bash
npx swa login -R apps-on-azure -n apps-on-azure-site
```

This may prompt you for your subscription and tenant information.  You can avoid these prompts by setting environment variables before you run the command:

```bash
export AZURE_SUBSCRIPTION_ID=`az account show --query "id" --output tsv`
export AZURE_TENANT_ID=`az account show --query "tenantId" --output tsv`
```

However, I find this is too much typing for an infrequent operation.  Mostly, I switch over to one of the other methods after I've deployed once.

Finally, let's deploy the code:

```bash
npx swa build
npx swa deploy -n apps-on-azure-site
```

This will build my site and deploy the code to the static web app.  Once the deployment is done, the URL of the site is displayed - I can click on it to view the site.

## Method 2: Azure Developer CLI

## Method 3: GitHub Actions

## Cleaning up resources

If you've been following along, you probably don't want the resources you created to stick around.  Even though the Azure Static Web Apps SKU is free, you only have 10 of them and you may want to use it for something else.  To clean up the resources, just delete the resource group:

```bash
az group delete -n apps-on-azure
```

This will take a little time.

## Final thoughts

I've also used Netlify and Vercel, and Azure Static Web Apps stacks up well against these guys, including the price point (you can't argue with free!). If your company is already on Azure or requires more robust private networking, Azure Static Web Apps supports that too.  Even if you are doing this on your own dime, having the backing of one of the major clouds is a benefit.

## Further reading

* [Azure Static Web Apps](https://learn.microsoft.com/azure/static-web-apps/overview)
* [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/overview)
* [GitHub Actions](https://docs.github.com/actions)
