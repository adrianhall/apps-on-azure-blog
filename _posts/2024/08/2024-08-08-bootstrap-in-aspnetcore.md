---
title:  "Building Bootstrap apps from SASS with ASP.NET Core"
date:   2024-08-08
categories: dotnet
tags: [ tips, aspnetcore, csharp, scss, bootstrap ]
image: "/assets/images/2024/08/2024-08-08-banner.jpg"
header:
  image: "/assets/images/2024/08/2024-08-08-banner.jpg"
  teaser: "/assets/images/2024/08/2024-08-08-banner.jpg"
---

I'm building a new web application with ASP.NET Core, and I'm using [Visual Studio Code][vscode] with the [C# Dev Kit][devkit] so that I can really dive deep into the benefits and problems of using VS Code as a Visual Studio replacement. A frontend project is a good one to start with since I can check out the ways that the solution is presented while still having all the goodness of the VS Code development experience for JavaScript and TypeScript.  As part of the application, I wanted to build a lean Bootstrap CSS file with some of my customizations in there. Along the way, I learned a couple of new things about building an SCSS pipeline right inside the ASP.NET Core pipeline.  So, how did I do it?

## Client library management

Visual Studio has a handy "Add Client Library..." gesture that allows you to add client libraries to your application.  It's based on a command line tool called [libman]. You don't need Visual Studio to use libman, however. You just have to install the libman tool globally:

```bash
dotnet tool install -g Microsoft.Web.LibraryManager.Cli
```

This will install the tool in [your normal location for global tools][globaltools].  It's a good idea to add this directory to your PATH permanently.

Next, you need to create a `libman.json` file in your frontend web project.  The easiest way to do this is to change directory to your frontend web project and run `libman init` and it will prompt you for the information it needs.  You can also just create the file.  It looks like this:

```json
{
  "version": "1.0",
  "defaultProvider": "unpkg",
  "libraries": []
}
```

To add a library, you can either run `libman install` or you can edit the `libman.json` file and then run `libman restore`.

> If you are building within a CI/CD pipeline, then don't forget to adjust your pipeline definition to install the libman tool and then run libman restore on your frontend projects.

The `unpkg` provider refers to `unpkg.com` - a mirror of the npm package repository for client developers. You can also use `cdnjs` or `jsdelivr` as they provide similar functionality.  By default, libraries are written to `wwwroot/lib`, but you can also that by specifying the `defaultDestination` property within the JSON file.

## Add Client libraries to your project

I used the following:

```bash
libman install jquery
libman install bootstrap
libman install bootstrap-icons
```

You'll see them get installed into the `wwwroot/lib` directory for you.

> It's a good idea to add the `wwwroot/lib` directory to your `.gitignore` file at this point.

## Build an SCSS pipeline

I'm not done yet, because the whole point of this is to create an SCSS pipeline so I can generate my site.css file and use that.  This is done by a set of packages called *WebOptimizer*.  Let's take a look at how to use it.

### 1. Add packages

I added the following packages to my project:

```xml
    <PackageReference Include="JavaScriptEngineSwitcher.Extensions.MsDependencyInjection" Version="3.24.1" />
    <PackageReference Include="JavaScriptEngineSwitcher.V8" Version="3.24.2" />
    <PackageReference Include="LigerShark.WebOptimizer.Core" Version="3.0.422" />
    <PackageReference Include="LigerShark.WebOptimizer.Sass" Version="3.0.120" />
    <PackageReference Include="Microsoft.ClearScript.V8.Native.linux-arm" Version="7.4.5" />
    <PackageReference Include="Microsoft.ClearScript.V8.Native.linux-arm64" Version="7.4.5" />
    <PackageReference Include="Microsoft.ClearScript.V8.Native.linux-x64" Version="7.4.5" />
    <PackageReference Include="Microsoft.ClearScript.V8.Native.osx-arm64" Version="7.4.5" />
    <PackageReference Include="Microsoft.ClearScript.V8.Native.osx-x64" Version="7.4.5" />
    <PackageReference Include="Microsoft.ClearScript.V8.Native.win-arm64" Version="7.4.5" />
    <PackageReference Include="Microsoft.ClearScript.V8.Native.win-x64" Version="7.4.5" />
    <PackageReference Include="Microsoft.ClearScript.V8.Native.win-x86" Version="7.4.5" />
```

The main packages here are the `LigerShark` packages.  The rest are support for the V8 JavaScript runtime on each platform.

### 2. Add pipeline processing to your Program.cs

Your Program.cs (or Startup.cs, if you are using that form) is split up into two parts.  The first is the services section and the second is the middleware section.  In the services section, add the following:

```csharp
// Web Optimizer
builder.Services.AddJsEngineSwitcher(options =>
{
    options.AllowCurrentProperty = false;
    options.DefaultEngineName = V8JsEngine.EngineName;
}).AddV8();
builder.Services.AddWebOptimizer(pipeline => {
    pipeline.AddScssBundle("/css/site.css", "/css/site.scss");
});
```

This configures the SCSS pipeline to build `wwwroot/css/site.css` by compiling the `wwwroot/css/site.scss` file.  We'll get onto that in a little bit.  There are additional things you can do here.  For example, I can minify my CSS file in production:

```csharp
builder.Services.AddWebOptimizer(pipeline => {
  pipeline.AddScssBundle("/css/site.css", "/css/site.scss");
  if (!builder.Environment.IsDevelopment())
  {
    pipeline.MinifyCssFiles();
    pipeline.AddFiles("text/css", "/css/*");
  }
})
```

When you do this, your link (which we will see later) will show up like this:

```html
<!-- In Development -->
<link rel="stylesheet" href="/css/site.css">

<!-- In Production -->
<link rel="stylesheet" href="/css/site.css?v=I0IYlZ7jU-7f78mcHzDcQSfkCBo">
```

In production, your CSS file is also minified.  The query string addition is a feature known as "cache-busting".

In the middleware section, add the following:

```csharp
app.UseWebOptimizer();
app.UseStaticFiles();
app.UseRouting();
```

You likely already have `.UseStaticFiles()` and `.UseRouting()`.  You need to ensure that the `.UseWebOptimizer()` is added before these two.  If you are using response compression, then the `.UseWebOptimizer()` needs to come AFTER that.

### 3. Add tag helpers

In your `_ViewImports.cshtml` file, add the following line:

```csharp
@addTagHelper *, WebOptimizer.Core
@addTagHelper *, Microsoft.AspNetCore.Mvc.TagHelpers
```

Note that the added tag helper happens before the standard tag helper.

### 4. Add settings to your appsettings.json

You can control the pipeline within the `appsettings.json` file.  I have the following in my `appsettings.json` file:

```json
  "webOptimizer": {
    "enableCaching": true,
    "enableMemoryCache": true,
    "enableDiskCache": true,
    "enableTagHelperBundling": true,
    "allowEmptyBundle": true
  }
```

... and the following in my `appsettings.Development.json` file:

```json
  "webOptimizer": {
    "enableCaching": false,
    "enableMemoryCache": false,
    "enableTagHelperBundling": false,
    "allowEmptyBundle": false
  }
```

This ensures that my CSS file is cached by the server in-memory (with a backing disk cache) when running in production. However, caching (and cache-busting) is turned off during development so that I only need to reload my page to pick up the CSS changes when I am rapidly working. There is also support for CDN URL prefixing if needed.

### 5. Create a site SCSS file

Create the file `wwwroot/css/site.scss` file with the following contents:

```scss
// Bootstrap: Core
@import "../lib/bootstrap/scss/functions";

// Override the bootstrap variables here

// Bootstrap: Configuration
@import "../lib/bootstrap/scss/variables";
@import "../lib/bootstrap/scss/variables-dark";
@import "../lib/bootstrap/scss/maps";
@import "../lib/bootstrap/scss/mixins";
@import "../lib/bootstrap/scss/utilities";

// Bootstrap: Layout & components
@import "../lib/bootstrap/scss/root";
@import "../lib/bootstrap/scss/reboot";
@import "../lib/bootstrap/scss/type";
@import "../lib/bootstrap/scss/images";
@import "../lib/bootstrap/scss/containers";
@import "../lib/bootstrap/scss/grid";
@import "../lib/bootstrap/scss/tables";
@import "../lib/bootstrap/scss/forms";
@import "../lib/bootstrap/scss/buttons";
@import "../lib/bootstrap/scss/transitions";
@import "../lib/bootstrap/scss/dropdown";
@import "../lib/bootstrap/scss/button-group";
@import "../lib/bootstrap/scss/nav";
@import "../lib/bootstrap/scss/navbar";
@import "../lib/bootstrap/scss/card";
@import "../lib/bootstrap/scss/accordion";
@import "../lib/bootstrap/scss/breadcrumb";
@import "../lib/bootstrap/scss/pagination";
@import "../lib/bootstrap/scss/badge";
@import "../lib/bootstrap/scss/alert";
@import "../lib/bootstrap/scss/progress";
@import "../lib/bootstrap/scss/list-group";
@import "../lib/bootstrap/scss/close";
@import "../lib/bootstrap/scss/toasts";
@import "../lib/bootstrap/scss/modal";
@import "../lib/bootstrap/scss/tooltip";
@import "../lib/bootstrap/scss/popover";
@import "../lib/bootstrap/scss/carousel";
@import "../lib/bootstrap/scss/spinners";
@import "../lib/bootstrap/scss/offcanvas";
@import "../lib/bootstrap/scss/placeholders";

// Bootstrap: Helpers & utilities
@import "../lib/bootstrap/scss/helpers";
@import "../lib/bootstrap/scss/utilities/api";
```

This is the basic version with the entirity of Bootstrap in it.  You can probably comment out imports to make your CSS leaner.  You can also add your own customizations in and add your own imports easily.  I normally add a file `_overrides.scss` to the same directory, then use `@import "overrides";` where I've added the comment about overriding bootstrap variables.  This allows me to see which customizations I've done.

### 6. Add the link to your Razor files

You can add the link to your CSS file just like normal:

```html
<link rel="stylesheet" href="~/lib/bootstrap-icons/font/bootstrap-icons.css">
<link rel="stylesheet" href="~/css/site.css">
```

I've put both a link to a library (in this case, the Bootstrap Icons font) and a link to my generated stylesheet. 

Now, run that app!  You can see the generated CSS file.  It's automatically regenerated on request in development mode (if you've followed the instructions here) so you don't need to restart the server.  In production mode, you can set up both an in-memory cache and an on-disk cache.  You can also configure your app to output a CDN URL instead, allowing you to cache the CSS file at the edge.

## Final thoughts

The WebOptimizer library is full of features that allow you to fine-tune your CSS and JavaScript bundles.  It's become my go-to library for this functionality (yes, above the normal Web Compiler extension in the Visual Studio marketplace).  Paired with libman, it makes working with client-side libraries a breeze.  You can write your stylesheets in SCSS and use TypeScript for interactivity.  The WebOptimizer handles transpiling, bundling, autoprefix, and minifying for you (given the right plugins and configuration) with different pipeline settings for production vs. development.

## Further reading

* [Bootstrap customization](https://getbootstrap.com/docs/5.3/customize/overview/)
* [WebOptimizer](https://github.com/ligershark/WebOptimizer)
* [WebOptimizer SASS Compiler](https://github.com/ligershark/WebOptimizer.Sass)

[vscode]: https://code.visualstudio.com/
[devkit]: https://marketplace.visualstudio.com/items?itemName=ms-dotnettools.csdevkit
[libman]: https://learn.microsoft.com/aspnet/core/client-side/libman/
[globaltools]: https://learn.microsoft.com/dotnet/core/tools/global-tools#install-a-global-tool
