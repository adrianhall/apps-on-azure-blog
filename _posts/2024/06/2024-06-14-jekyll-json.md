---
title:  "Social Media Automation: Build a Jekyll JSON Feed"
date:   2024-06-14
categories: automation
tags: [ jekyll, jsonfeed, liquid ]
header:
  image: "/assets/images/2024/06/2024-06-14-banner.png"
  teaser: "/assets/images/2024/06/2024-06-14-banner.png"
---

I am currently creating a social media posting automation system to complement this blog.  In the [last post]({% post_url 2024/06/2024-06-11-automation-1 %}), I took a look at the system architecture of the solution and provisioned the Azure resources that I need.  Today I am going to look at the first step in the process.  I need to produce a JSON file that contains the posts for the blog that an automated system can read and process.

Fortunately, someone has thoughtfully created a feed specification specifically for blogs.  Here is a simple example (from [their specification](https://www.jsonfeed.org/version/1.1/)):

```json
{
    "version": "https://jsonfeed.org/version/1.1",
    "title": "My Example Feed",
    "home_page_url": "https://example.org/",
    "feed_url": "https://example.org/feed.json",
    "items": [
        {
            "id": "2",
            "content_text": "This is a second item.",
            "url": "https://example.org/second-item"
        },
        {
            "id": "1",
            "content_html": "<p>Hello, world!</p>",
            "url": "https://example.org/initial-post"
        }
    ]
}
```

There are even several libraries I can use to create this format.  However, it's a simple enough format and I don't actually need any extra libraries.  Jekyll allows me to create content using [Liquid](https://shopify.github.io/liquid/) - the same templating language that is used for creating themes for Jekyll.

## Create a layout

Jekyll layouts are templates written with the Liquid templating language that wrap around your content.  They allow you to have the source code for your template in one place so you don't have to repeat things like your navigation and footer on every page.  Layouts live in the `_layouts` directory. 

Jekyll comes with three default layouts and your template will add more.  For instance, the [Minimal Mistakes template](https://mmistakes.github.io/minimal-mistakes/) that I use comes with the 'single' template that is used on most pages.  You can create your own layouts easily though.  They don't have to be HTML templates either.  You can generate any static content, including JSON, XML, CSS, and more.  

Let's take a look at my `_layouts/jsonfeed.json` template:

{% highlight text linenos %}{% raw %}
---
---
{% assign postcount = site.jsonfeed.count | default: 20 %}
{
    "version": "https://jsonfeed.org/version/1.1",
    "title": {{ site.jsonfeed.title | default: site.title | jsonify }},
    "description": {{ site.jsonfeed.description | default: site.description | jsonify }},
    "favicon": "{{ site.jsonfeed.icon | default: site.logo | absolute_url }}",
    "language": {{ site.jsonfeed.language | default: site.locale | jsonify }},
    "home_page_url": "{{ "/" | absolute_url }}",
    "feed_url": "{{ site.jsonfeed.url | default: "/feed.json" | absolute_url }}",
    "items": [{% for article in site.posts limit: postcount %}
        {
            "id": "{{ article.id | lstrip: "/" | slugify }}",
            "url": "{{ article.url | absolute_url }}",
            "title": "{{ article.title | replace: '|', '&#124;' | markdownify | strip_html | strip_newlines | escape_once }}",
            "date_published": "{{ article.date | date: "%Y-%m-%d" }}",
            "categories": {{ article.categories | jsonify }},
            "tags": {{ article.tags | jsonify }},
            "socialmedia": {{ article.socialmedia | jsonify }},
            "content_text": {{ article.content | markdownify | strip_html | strip_newlines | jsonify }}
        }{% unless forloop.last %},{% endunless %}
    {% endfor %}]
}
{% endraw %}{% endhighlight %}

If you are relying on Intellisense within Visual Studio Code to make sure you don't make any mistakes, it won't work with templates.  The template is not valid JSON until it gets generated.

> Want to learn more about Jekyll Liquid?  Here is [a great cheat sheet](https://www.fabriziomusacchio.com/blog/2021-08-12-Liquid_Cheat_Sheet).

Let's take a look at one line in this: line 21.  This is typical of a lot of lines.  Take the article content (which is supplied to us in HTML form), turn it into markdown, strip out any remaining HTML, then strip out the new lines (who needs them anyway), and finally turn it into a JSON string.

You can find a listing of all the [site-specific](https://jekyllrb.com/docs/variables/#site-variables) and [page-specific](https://jekyllrb.com/docs/variables/#page-variables) variables that Jekyll provides within the Liquid templating language.  All the site-specific ones can be overridden using the `_config.yml` file, and all the page-specific ones can be updated using the front matter at the top of each page.

For this layout, I've created a new section that I can put in the `_config.yml` called `jsonfeed`.  It will look something like this:

```yaml
jsonfeed:
  title: My Blog Title
  description: My blog description
  icon: /assets/images/logo.png
  language: en
  url: /feed.json
  count: 20
```

However, none of these need to be specified because there are defaults based on the site variables.  It's just a useful way to provide overrides for the common fields.

On the page side, I've added a "social" section.  I expect this to look something like this:

```yaml
socialmedia:
  reddit:
    - r/azure
    - r/jekyll
  tags:
    - azure
```

When it comes to posting, the page tags and the `social.tags` will be added as hash tags to whatever I post.  If I need something specific for a social network (for example, the sub-reddit to post to), then I'll add it into this section.

## Create the feed

I created the feed in the `_pages` section.  The `feed.json` file looks like this:

```json
---
layout: jsonfeed
permalink: /feed.json
---
```

I specify the default layout for everything in the `_pages` directory in `_config.yml` with this bit of YAML:

```yaml
defaults:
  - scope:
      path: ""
      type: pages
    values:
      layout: single
```

Adding the `layout: jsonfeed` overrides this value and specifies that I want "my layout" instead of the default.  Then I specify where I want the link to go.

## The result

Here is a snippet of the result for this blog:

```json
{
  "version": "https://jsonfeed.org/version/1.1",
  "title": "Apps on Azure",
  "description": "A blog about building secure and optimized apps for the Azure cloud.",
  "favicon": "/assets/images/logo.png",
  "language": "en-US",
  "home_page_url": "/",
  "feed_url": "/feed.json",
  "items": [
    {
      "id": "automation-2024-jekyll-json",
      "url": "/automation/2024/2024-06-14-jekyll-json.html",
      "title": "Social Media Automation: Build a Jekyll JSON Feed",
      "date_published": "2024-06-14",
      "categories": ["automation"],
      "tags": ["jekyll","jsonfeed"],
      "socialmedia": null,
      "content_text": "I am currently creating a social media posting automation system to complement this blog.  In the last post, I took a look at the ..."
    },

    {
      "id": "automation-2024-automation-1",
      "url": "/automation/2024/2024-06-11-automation-1.html",
      "title": "Social Media Automation: The infrastructure",
      "date_published": "2024-06-11",
      "categories": ["automation"],
      "tags": ["bicep","azd","azure","functions","cosmosdb"],
      "socialmedia": null,
      "content_text": "In my last series, I built this blog, including all the infrastructure and automated posting.  However, a lot of the social media posting is done by hand.  Yes, there are social media calendars like Hootsuite and ..."
    } 
  ]
}
```

You can run `bundle exec jekyll build` to build the site.  The `feed.json` file will be in the `_site` directory on your local disk.  This helps with debugging problems with this file.

I've shortened the content field in this example, since the actual strings are long.  You can see a small problem here.  When there is no "social-media" section in the front-matter, the value is null.  I would really rather see a default "reddit" value here.  I can do this in `_config.yml` by specifying the defaults.  Here is a snippet:

```yaml
defaults:
  # _posts
  - scope:
      path: ""
      type: posts
    values:
      excerpt_separator: <!--more-->
      layout: single
      author_profile: true
      read_time: true
      comments: true
      share: true
      related: true
      toc: true
      socialmedia:
        reddit:
          - r/azure
```

This will then produce entries like this:

```json
{
    "id": "automation-2024-automation-1",
    "url": "/automation/2024/2024-06-11-automation-1.html",
    "title": "Social Media Automation: The infrastructure",
    "date_published": "2024-06-11",
    "categories": ["automation"],
    "tags": ["bicep","azd","azure","functions","cosmosdb"],
    "socialmedia": {"reddit":["r/azure"]},
    "content_text": "In my last series, I built this blog, including all the infrastructure and automated posting.  However, a lot of the social media posting is done by hand.  Yes, there are social media calendars like Hootsuite and ..."
},
```

## Final thoughts

Not everything has to be written in code.  In many cases, the initial working data for your code can be easily generated in other ways.  Jekyll (and Liquid by extension) is great for this.  While JSONFeed is not a standard by any stretch, it's good to take a look at the work that others have put into this space and lean on them.

## Further reading

* [JSONFeed](https://jsonfeed.org)
* [Jekyll variables](https://jekyllrb.com/docs/variables)
* [Shopify Liquid](https://shopify.github.io/liquid/)
* [Jekyll Liquid cheat sheet](https://www.fabriziomusacchio.com/blog/2021-08-12-Liquid_Cheat_Sheet)
