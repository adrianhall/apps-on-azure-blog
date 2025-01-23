---
title:  "The Datasync Community Toolkit - Day 7: Client authentication"
date:   2025-01-23
categories: datasync
tags: [ csharp, aspnetcore, datasync ]
image: "/assets/images/2025/01/2025-01-23-banner.png"
header:
  image: "/assets/images/2025/01/2025-01-23-banner.png"
  teaser: "/assets/images/2025/01/2025-01-23-banner.png"
---

This article is the seventh in a series of articles about the [Datasync Community Toolkit][toolkit], which is a set of open source libraries for building client-server applications where the application data is available offline. The Datasync Community Toolkit allows you to connect to any database, use any authentication, and provides robust authorization rules. You implement each side of the application (client and server) using .NET - [ASP.NET Core Web APIs](https://learn.microsoft.com/training/modules/build-web-api-aspnet-core/) on the server side, and any .NET client technology (including [WPF](https://wpf-tutorial.com/), [WinUI](https://learn.microsoft.com/windows/apps/winui/winui3/) and [MAUI](https://dotnet.microsoft.com/apps/maui)) on the client side.

This is the second article about the client-side of things.  If you missed the server-side articles, check out this set:

1. [Creating a service project]({% post_url 2024/10/2024-10-08-datasync-part1 %})
2. [The standard repositories]({% post_url 2024/10/2024-10-21-datasync-part2 %})
3. [Custom repositories]({% post_url 2024/11/2024-11-01-datasync-part3 %})
4. [Access control restrictions]({% post_url 2024/11/2024-11-12-datasync-part4 %})
5. [Real-time notifications]({% post_url 2024/11/2024-11-22-datasync-part5 %})

And if you missed the first article about the client-side of things, check out:

1. [Client basics]({% post_url 2025/01/2025-01-06-datasync-part6 %})

Today, I'm going to be implementing authentication in both the server and client.  Both sides of the client-server relationship must agree on authentication, so it's only natural that you have to configure authentication in both places.  I'm going to be using Microsoft Entra ID for this, configured in a manner that allows you to use your outlook.com address.  I'm going to be using MSAL throughout to make it easier.  This is not a blog post on how to implement authentication generally, and - as you will see - you can use any authentication mechanism as long as the client and server agree.

I'm going to start with the end point of the datasync-day6.

## Adding authentication to the server app.

Let's start with the server app.  First, you need to create an app registration:

1. Sign in to the [Azure portal](https://portal.azure.com).  Select the correct tenant and subscription if you have access to multiple environments.
2. Search for and select **Microsoft Entra ID**.
3. Under **Manage**, select **App registrations** > **New registration**.
   * **Name**: Enter a name for the application.  e.g. "Datasync Day7".  Users of your app will see this name.
   * **Supported account types**: Select **Accounts in any organizational directory (Any Microsoft Entra directory - Multitenant) and personal Microsoft accounts (e.g. Skype, Xbox)**.
4. Select **Register**.
5. Under **Manage**, select **Expose an API** > **Add a scope**.
6. Access the default application ID URI by selecting **Save and continue**.
7. Enter the following details in the form:
   * **Scope name**: `access_as_user`
   * **Who can consent?**: **Admins and users**
   * **Admin consent display name**: `Access app`
   * **Admin consent description**: `Access app description`
   * **User consent display name**: `Access app`
   * **User consent description**: `Access app description`
   * **State**: `Enabled`
8. Select **Add scope** to complete the process.

Note that value of the scope (similar to `api://client-id/access_as_user`) - you will need this when configuring the client.

Finally, select **Overview** and note the **Application (client) ID** in the **Essentials** section.  You'll need this when configuring the backend service.

If you go to the [datasync-day7](https://github.com/adrianhall/samples/blob/main/datasync-day7) repository, you'll note that the server app already has all the code added for you.  All you need to do is to add the client ID to the configuration.  I do this via user secrets during development:

1. Open the `datasync-day7.sln` file.
2. Right click on the `ServerApp` project, and select **Manage User Secrets**.
3. Fill in the details to look like the following:

    ```json
    {
      "AzureAd": {
        "ClientId": "fill-in-your-client-id-here"
      }
    }
    ```

If you are deploying to Azure App Service, you'll want to create an app setting named `AzureAd__ClientId` instead.  Don't put this in your `appsettings.json` file - it's not quite a secret, but you don't want it checked in to a GitHub repository.  If you want to read more about configuring a Web API to use Microsoft Entra ID, read the [official documentation](https://learn.microsoft.com/entra/identity-platform/index-web-api).

If you run the server app and browse to 'https://localhost:7181/tables/todoitem' at this point, you will receive a "401 Unauthorized" error.  This indicates that the API is being protected appropriately.

## Adding authentication to the client app

You may remember that I created a WPF client application in day6.  I'm going to use the same application and just add authentication to it.  Setting up the client is more complex than the server side.  There are also different mechanisms for creating the required registration for each platform.  I'm covering WPF here, but you should look at the MSAL tutorials for MAUI, WinUI3, or whatever client platform you are using.  The thing you need to understand is how to get a token that you can then send to the backend to authorize the request.

1. Back in the Microsoft Entra ID page on the Azure portal, select **App registrations** > **New registration**.
2. In the **Register an application** page, fill in the form:
   * **Name**: Enter `datasync-day7-wpf` (to distinguish from the one used by the backend service).
   * **Supported account types**: Select **Accounts in any organizational directory (Any Microsoft Entra directory - Multitenant) and personal Microsoft accounts (e.g. Skype, Xbox)**.
   * **Redirect URI**: Select **Public client (mobile & desktop)**, and enter the URL `http://localhost`.
3. Select **Register**.
4. Select **API permissions** > **Add a permission** > **My APIs**, then select the app registration you created earlier for your backend service.  In some circumstances, you may find the app registration under "APIs my organization uses" instead.
5. Under **Select permissions**, select `access_as_user`, then select **Add permissions**.
6. Select **Authentication** > **Mobile and desktop applications**.
7. Check the following boxes:
   * next to `https://login.microsoftonline.com/common/oauth2/nativeclient`.
   * next to `msal{client-id}://auth` - the client-id will be your client ID.
9. Select **Save** at the bottom of the page.
10. Finally, select **Overview** and make a note of the **Application (client) ID**.  You'll need this along with the scope (from earlier) to configure your client app.

I've defined three redirect URLs here:

* `http://localhost` is used by WPF applications.
* `https://login.microsoftonline.com/common/oauth2/nativeclient` is used by WinUI applications.
* `msal{client-id}://auth` is used by MAUI applications.

Next, update the `Constants.cs` file.  You'll need to specify three bits of information:

* The service URI (normally `https://localhost:7181` for running locally).
* The Application (client) ID for the client registration (the one you just did).
* The scope for the web API.

The rest of the work has been done for you, but I'll be pointing out how it's done next.

### Step 1: Create an identity client

MSAL uses a `PublicClientApplication` to handle authentication.  It's based on your native client application ID and you create it like this:

```csharp
var client = PublicClientApplicationBuilder.Create(Constants.ApplicationId)
    .WithAuthority(AzureCloudInstance.AzurePublic, "common")
    .WithRedirectUri("http://localhost")
    .WithWindowsEmbeddedBrowserSupport()
    .Build();
```

This requires `Microsoft.Identity.Client` and `Microsoft.Identity.Client.Desktop` from NuGet, the latter being specific to desktop apps.  There are slightly different versions for WinUI3 and MAUI, but the essence remains the same.  I'm using the `CommunityToolkit.Mvvm` library for dependency injection.  In the app, I've injected the `IPublicClientApplication` interface as a singleton.

### Step 2: Write a method to do the authentication

You need something that you can call that returns an authentication token.  For this project, I've placed the function in the `OnlineTodoService`:

```csharp
public async Task<AuthenticationToken> GetAuthenticationToken(CancellationToken cancellationToken = default)
{
    var accounts = await IdentityClient.GetAccountsAsync();
    AuthenticationResult? result = null;
    try
    {
        result = await IdentityClient.AcquireTokenSilent(Constants.Scopes, accounts.FirstOrDefault()).ExecuteAsync(cancellationToken);
    }
    catch (MsalUiRequiredException)
    {
        result = await IdentityClient.AcquireTokenInteractive(Constants.Scopes).WithUseEmbeddedWebView(true).ExecuteAsync(cancellationToken);
    }
    catch (Exception ex)
    {
        Debug.WriteLine($"Error: Authentication failed: {ex.Message}");
    }

    return new AuthenticationToken
    {
        DisplayName = result?.Account?.Username ?? "",
        ExpiresOn = result?.ExpiresOn ?? DateTimeOffset.MinValue,
        Token = result?.AccessToken ?? "",
        UserId = result?.Account?.Username ?? ""
    };
}
```

The `IdentityClient` here is retrieved via dependency injection.  The `AuthenticationToken` is a part of the `CommunityToolkit.Datasync.Client` library that we are already using.  Again, this is pure MSAL - nothing to do with the Community Toolkit Datasync library - you are retrieving a token to use by the library.  If you were using Facebook auth or the ASP.NET Core identity library, the same thing happens.  Your task in this method is "do whatever is necessary to get an access token".

Note the signature of the method - this is important as the `GenericAuthenticationProvider` we'll use in a minute requires a specific signature.

### Step 3: Enable automatic authentication

The final step is to add an authentication handler to the HTTP pipeline for the client.  The authentication handler automatically calls the provided method to get an authentication token whenever it needs one.  It transparently handles cases when the token needs to be refreshed, which allows you to do silent authentication when you have a refresh token.

```csharp
var clientOptions = new HttpClientOptions()
{
    Endpoint = new Uri(Constants.ServiceUri),
    HttpPipeline = [
        new GenericAuthenticationProvider(GetAuthenticationToken)
    ]
};
```

The `GenericAuthenticationProvider` is a `DelegatingHandler` that you can actually use with any `HttpClient` for authentication.  It adds the token from the returned `AuthenticationToken` as an authorization header to each HTTP request going through the configured client.

Run the application, click **Refresh** and see the authentication happen!

If you want to use the same authentication with a regular HTTP client, use the following:

```csharp
var clientFactory = new HttpClientFactory(clientOptions);
var httpClient = clientFactory.CreateClient();
```

The `HttpClientFactory` class is provided inside the `CommunityToolkit.Datasync.Client.Http` namespace.  Doing this allows you to use generic HTTP calls to call you non-datasync web APIs using the same authentication, logging, etc.

## Wrap-up

The main problem with authentication in datasync is the same as authentication in a Web API world.  You have to get that going before you can configure the datasync library to use it.  once you have configured authentication to work, it's as simple as an additional single line in the client options.  You can also use the same mechanism in your own HTTP clients.  This makes building authenticated clients for other purposes (like calling a non-datasync web API) simple as well.

## Further reading

* [The datasync-day7 repository code](https://github.com/adrianhall/samples/tree/main/datasync-day7)
* [Microsoft Identity Platform](https://learn.microsoft.com/entra/identity-platform/)
* [Microsoft Identity for Web API](https://learn.microsoft.com/entra/identity-platform/index-web-api)
* [Microsoft Identity for Desktop](https://learn.microsoft.com/entra/identity-platform/index-desktop)
* [Microsoft Identity for Mobile](https://learn.microsoft.com/entra/identity-platform/index-mobile)