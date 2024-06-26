---
title:  "The State of React state management in 2024"
date:   2024-06-25
categories: react
tags: [ react, comparison ]
header:
  image: "/assets/images/2024/06/2024-06-25-banner.png"
---

I've been away from React development for a while.  I stupidly asked what the best way to create a React app was in 2024 on the [React subreddit](https://reddit.com/r/react), and found that reddit is not a friendly or welcoming community. For those wondering, there are three ways of creating a React app - [Vite](https://vitejs.dev), [Remix](https://remix.run), and [NextJS](https://nextjs.org) - but the community suggests Vite.

Given the somewhat frosty reception I got on the React subreddit, I decided to do my own research across a number of topics for a new project - a social media calendar and scheduling app for my blog. I looked across the main web frameworks (React, Vue, Angular, and Svelte) and chose React as my first one because of my familiarity with its concepts, but also the large ecosystem of tools and libraries.  The next question is "what libraries should I use?"

And here is the first one - state management.

I'm going to limit myself to just 1 hour per library.  This will enable me to see how easy it is to get started in a real world project.  I'm going to score each library across a number of factors:

* Ease of use / developer experience.
* Integration with standard React libraries.
* Tutorial quality.
* Documentation quality - beginner.
* Documentation quality - intermediate to advanced.
* API documentation.
* Availability of in-browser debugging tools.
* Quality of official sample code.
* Community resource availability.

That's 9 categories, each of which are scored out of 10.  I've then weighted the ease of use, integration, and beginner documentation scores to get an eventual score out of 100.

Who are the contenders?  When I left, Redux was the king of the state management services.  In 2024, I had no clue, so I went to the NPM Weekly Downloads and took the top 7 spots:

* [react-redux]
* [zustand]
* [xstate]
* [mobx]
* [jotai]
* [recoil]
* [valtio]

To that I added the React [useContext() hook](https://react.dev/reference/react/useContext) - i.e. "no real state management" - to see if I even needed a state management library.  Interestingly, only two libraries (react-redux and mobx) are in the list from the last time I did this research.

For each library being considered, I went through whatever tutorials they provided, then I tried to integrate the library into my own project (which has a number of state requirements, including local persistence and data fetching requirements).

Everyone has their own favorite libraries, so I've tried to be objective in the comparison.  However, I think the documentation is so critical to learning a library that it's at the top of my list when it comes to things to do well.  I've weighted developer experience and the early learning documentation higher than the other parts of the comparison.

A mentor once told me that if you can't think of anything to do, write some documentation.  I have followed that axiom for most of my career as it is so critical to others understanding what you are trying to do.

On to the comparisons!

## React Redux - 73.5 points

[React Redux][react-redux] is one of three libraries by the Redux team - including Redux itself (which is separate and does not depend on React) and the Redux Toolkit (an "official, opinionated, batteries-included toolset of efficient Redux development).  Redux has been around for almost as long as React and has the advantages there, with [10.5K stars on GitHub](https://github.com/reduxjs/redux-toolkit).  Since the Redux Toolkit is "how to use Redux today", that's what I used for my experimentation.

Let's go over some of the stuff that's important here.  Redux is a "reducer-style" state management library.  

There are many ways of doing state management.  I'll introduce the other styles of state management libraries as they are encountered. "Reducer-style" was popularized by the Flux pattern that influenced the early state management libraries for React.  Flux is a one-way data flow pattern.  The view executes actions, which adjusts state, which updates the view. I personally like reducer-style state management because the state changes can be individually unit tested with ease.  Sometimes, testing the interactions within your library is hard.  Reducer-style state management makes the state immutable except (in my mind) during the reducer.  In a reducer-style state management library, you write reducers - units of work that take the current state plus the change you want to make to the state and produce a brand new state.  The brand new state then flows through the application changing the UI in whatever way is needed.  Because the state is only changed within a reducer (which is generally a function without side effects), you can easily test it.

Let's look at some of the scoring and why:

* Developer experience - 6/10.   I'm putting this one right in the middle because it is the grand-daddy of all the state management libraries, but also because there are a lot of concepts to learn and a lot of boiler plate code to write.  I've got familiarity with the library before Redux Toolkit was released, so I can see that using the toolkit does reduce the boiler plate code - but it's still there.  They've also added some additional stuff that you should write, like slicers.  These are actually optional, but enhance the experience.  Bonus: it supports TypeScript.  This may be obvious today, but the bigger the application, the more you appreciate having TypeScript available for all your applications.

* Integration - 8/10.  I'm looking for three specific integrations - data fetching, react-router, and state persistence.  There is a plugin for data-fetching called [RTK Query](https://redux-toolkit.js.org/rtk-query/overview), which is a great addition that will allow you to work with REST and GraphQL backends and handles caching, spinners, and optimistic updates for you.  It, like the main library, requires a lot of setup.  This should be expected since there are lots of backends.  Fortunately, there is a lot of documentation for this feature, including example code.  On the other two integrations, there are specific plugins - so its got everything you should need.

* Tutorial quality - 9/10.  Redux Toolkit provides two tutorials - an "essentials" tutorial which is your basic beginner walk through and a "fundamentals" tutorial that provides "how Redux works" for a more intermediate developer.  I love that they cater to both sets of audiences and don't leave them high and dry after getting started. They seem to have something against Safari and Edge browsers, however, preferring to only tell you the links to the dev tools for Chrome and Firefox.

* Documentation quality (beginner) - 9/10.  The [Redux Toolkit documentation](https://redux-toolkit.js.org/) has a wealth of beginner information, but - importantly - starts with "why should I use this library."  This is potentially the single most important question that a beginner comes to the documentation site to answer.  The tutorials cover the basics and move you through the process of learning Redux easily.

* Documentation quality (intermediate) - 9/10.  The main thing an intermediate person wants is to understand the concepts of the library.  This helps with understanding what is going on when things don't go as expected. There is an explicit "fundamentals" tutorial that covers the concepts in great detail.  Unfortunately, there are lots of concepts.  The tutorial walks you through them.  It's interesting that I could cover both the essentials (getting started) tutorial and fundamentals tutorial within the hour.  I think the only thing that would have made the documentation set better is to have a glossary of terms that provided the concept together with the short description and a link to the tutorial section where it is discussed (then link the glossary all over the place).

* API documentation - 4/10.  So, there is API documentation - yay!  It's in three different places.  You have to know the package to find the method and API docs for it.  If you go to the API reference for Redux (the core library), there are links to the other two libraries.  However, they go to the main documentation page for the library - not the API reference.  That makes finding API reference information really hard work.  Once you get to the actual API reference for the method you are curious about, the definition is there, but there are no examples on how to use the API, nor are there links to samples usage of the API.

* In-browser debugging tools - 9/10.  There is a Redux DevTools extension and code within the library to interact with that extension.  You can do replays of your state changes (which is super cool).  They have a bias for Chrome and Firefox (even though the extension is available for Edge as well).  There is also a standalone package ([@redux-devtools/cli](https://www.npmjs.com/package/@redux-devtools/cli)) for remote debugging.

* Official sample code - 2/10.  Aside from the official starter kit and tutorial code, there isn't anything official.  However, because of the age of the library, I found plenty of non-official badly-written sample code on GitHub.  The lack of serious samples (that do more than the basics) is this libraries major downfall.

* Community resources - 10/10.  It's an old library, but still has an active Discord group, Stack Overflow community, and blogs, videos, and other material come out on a regular basis.  This is really a solid community.

Overall, I found Redux to have just gotten better since last I used it.

## Zustand - 25.3 points

Conceptually, Redux and [Zustand][zustand] are similar - they both use the "reducer-style" immutable state model.  Unlike redux (which is based on the context and hence uses wrapper "provider" components), Zustand uses hooks. But how do they rack up against one another?

* Developer experience - 6/10.  The store is a hook!  Hooks are easy!  So the story goes, anyways.  If you are using Zustand, you will write MUCH LESS CODE than the Redux equivalent.  However, the API is no where near as rich and I found it difficult to track what was going on at what time when I was coding.  Being a complete beginner is hard!  Bonus points for TypeScript out of the box.  Zustand does one thing incredibly simply and well, and it leaves everything else alone, so it doesn't cover all the use cases you might have.

* Integrations - 2/10.  There are no specific integrations for data fetching, react-router, or state persistence.  However, there are third-party libraries - heck, you could even use RTK Query for the data fetching part.  The third-party libraries list is just that - a list.  There is no organization, no opinions, nothing to aid the basic developer to see what is appropriate here.  There is no integration with react-router that I could find.

* Tutorial quality - 1/10.  There are no tutorials.  There is only a one-pager at the very first page of documentation called "getting started".   That's it.  The walk through doesn't even end up with a complete application.

* Documentation quality (beginner) - 1/10.  This is not a beginner friendly documentation set.  It starts with "Here is how to update state" with a long code listing (more than a page) and no explanation of what the code is doing or why.  You really need to invest in hooks, then Zustand itself to get from the absolute beginner to having a minimal amount of knowledge here.

* Documentation quality (intermediate) - 7/10.  This continues the theme.  The documentation set for Zustand was written for the Zustand developers.  There is a lot left unsaid, which just code samples.  Reading code is all well and good, but perhaps include an explanation every now and then?  I want to understand concepts, but I never got that far.

* API documentation - 0/10.  There is no API documentation.

* In-browser debugging tools - 0/10.  There is no in-browser debugging tools.  Fortunately, there is a third-party plugin that displays the store within React DevTools.  There is also a third-party plugin (that I didn't try) that purports to do time travel for debugging.  However, these are not official.

* Official sample code - 1/10.  There is a demo app, but you have to go hunting for it, since they don't have a direct link to their GitHub repository.  The examples have no README, so you are expected to understand what the app is doing by just reading the code.  The app looks like a simple counter app, so it's definitely not showing off anything complex.

* Community resources - 4/10.  There are a lot of Zustand 101 blog posts and videos, but not really anything more complex than that.  It's like everyone is stuck in the simplest examples.  One of the best resources I found was a [freecodecamp course](https://www.freecodecamp.org/news/zustand-course-react-state-management/) which built something a little more complex.

I'd be hard pressed to recommend Zustand to a beginner web app developer.  It's got a lot of merit with its simple design, but it relies too heavily on the community to produce what should be in the documentation as "official".

## XState - 51.3 points

[XState][xstate] has the prize for "least informative home page ever".  It's framework agnostic, so you can use the same library across React, Vue, and Svelte (and anything else you care to choose, I guess).  It has specific integrations for React, Vue, and Svelte.  Redux and Zustand mutate based on actions (or events), whereas XState changes based on states, which - I guess - aligns with finite state machines.  In a finite state machine, a program can only existing in one state and all states are known in advance.  This doesn't really align with how we think about state management in react.  We think of state as "random bits of data".  So this model hurt my head a little.

So let's take a deeper look.

* Developer experience - 6/10.  Any library will have some unique terminology and concepts.  It's inevitable considering no-one creates a library as a "me-too" library but with the intent of improving and releasing it. But I expect libraries to document the unique stuff really well.  Unfortunately, XState starts by assuming you know what a state machine is.  They bury their terminology down in the docs, and overload other common terms from the react world in their library to mean something different.  This makes understanding the flow really hard.  On the plus side, their code is unit testable easily, and their tooling is really good.  They even have a Visual Studio Code extension.  So it's a mixed bag here.

* Integrations - 2/10.  They have a persistence layer built in that stores the state in localStorage for you.  The library itself assumes all other integrations are your problem, so no react-router integration and no assistance with data fetching.
  
* Tutorial quality - 1/10.  Much like Zustand, there is only a one-pager called a quick start.  It isn't React friendly and you don't end up with a working application at the end.

* Documentation quality (beginner) - 5/10.  The beginner documentation set starts with core concepts like "State machines" and "Actor model", and only then answers the question "What is XState?"  Wow.  That should be the first page!  While this is marginally better than Zustand, the number of concepts you have to understand means this is not a beginner friendly library.  I suspect you would only use this model if you came from an academic background and already understood finite state machines.  One of the things that I did like is that Stately did a [Video series](https://www.youtube.com/playlist?list=PLvWgkXBB3dd6a3Iau-azlLDlGRY63_5it) which really mirrored their documentation.  However, I see what they did with an earlier version, so I have hopes this will be improved.

* Documentation quality (intermediate) - 7/10.  Like Zustand, where this documentation set excels is in the intermediate developer arena.  Once you understand the basics of XState, there is actually a wealth of information about the different types of actors and how you can use them, complete with examples.  I learned about finite state machines in college, so this isn't fresh information for me.  However, I could easily see where a lot of the power for this specific library came from.

* API Documentation - 5/10.  API documentation is very hit and miss in libraries.  The good things - every API is documented well and I especially love the examples that they provide to show the API call in context.  The bad things - they haven't reviewed everything, so the examples tend to be "markdown blobs" which don't lend themselves to copy/paste.  Also, their descriptions are lackluster a lot of the times.  For example, the "assign()" method has the description "Updates the current context of the machine".  That doesn't tell me when I would use it though.  The authors rely too heavily on examples and the example formatting is broken and has no context.

* In-browser debugging tools - 10/10.  Stately (who are the authors of XState) sell Stately Studio and a set of tools around that for teams.  It's obviously the reason for spending so much time on this library.  For the non-paid versions, though, there is still good tooling.  There is a VS Code extension and an inspector plugin that allows you to connect directly to XState actors or send inspection events.  There is also a CLI that is documented, but probably isn't for general use since its function doesn't seem to have anything to do with XState.

* Official sample code - 8/10.  There is [a wealth of examples](https://github.com/statelyai/xstate/tree/main/examples) maintained by the team of varying levels of complexity and well laid out so its easy to find your way around.  Each one has screen shots and a README.  My only real complaint here is that the relevant code is not commented.  If you are going to go through the effort of providing examples, actually document the code as to what it is there for and how it interacts with other bits of the code.

* Community resources - 4/10.  There are a lot of beginner tutorials in both blog and video form. There are also courses on how to use XState with React on Egghead, UDemy, and others. Unsurprisingly, there is also a bunch of blogs that say "don't use XState with React".  

As with Zustand, I'm not going to be recommending XState to beginners any time soon.  However, this library is in a better position and has a different mental model than Redux and Zustand.  I'm sure that there is a niche for this and a set of people for whom the mental model "clicks".

## MobX - 56.7 points

[MobX][mobx] was the second state management library I ever used.  It's rooted in functional reactive programming - most notably the concept of observables.  When I was developing Android applications (and mobile in general), observables and reactive concepts played a big part in what I did, so this fit with my mental model of state management at the time.

* Developer experience - 5/10.  When I think of developer experience, I think about finding the right API call based on what it does and providing "intellisense" to take the guess work out of writing code.  If I know the terminology or concepts, I should be able to just type code.  Developer experience with MobX is above average, but far from perfect.  As an example, they have "makeObservable" and "makeAutoObservable" - why did they not combine these into one so I didn't have to guess. Then they layer on terminology like "lazy observables", but they have no corresponding "makeLazyObservable()" method.  This means you basically have to have the documentation open while developing here.
  
* Integrations - 4/10.  As I did with the others, I looked at three integrations - react-router, data fetching, and persistence.  The short version here is that there is no integrations built in, but others have written libraries for these functions.  I think these are mostly because the library has been around for so long.  While you won't find support from the MobX crew, you will find libraries to do just about everything.

* Tutorial quality - 5/10.  To start with, they have a "A quick example" which is an example that fits on a page, and is then explained with a diagram.  Then they have a 10 minute interactive introduction.  Between the two, you're going to have a pretty good idea on the various components that make up a MobX system and how to use it in your app.

* Documentation quality (beginner) - 8/10.  There are good things and bad things here.  The bad thing is that the authors split the work between "MobX Core" and then "MobX and React".  They don't support any other integrations other than React - so why split them?  It would make more sense to have a documentation set that told you have to use MobX + React, then leave the details on how to use MobX in an appendix.  As a result, you have to get into heavy concepts before you actually start learning how to use MobX with React.  The good things - the MobX crew engages, encourages, and endorses the community by highlighting great videos and blog posts right in their docs.  They also have a book you can buy and sponsored video courses.

* Documentation quality (intermediate) - 7/10.  There is a whole section of their docs entitled "Tips & Tricks".  This is your conceptual guide and they do a good job of explaining these concepts along with good examples for the concepts they are explaining. (aside: what's the deal with the rockets?)  Having said that, some of the areas are hidden behind collapsible sections and they don't show off the latest stuff that makes the developer experience a good one (like decorators).

* API documentation - 9/10.  Oh - how I sing the praises of good API documentation.  It has a solid index with everything in one place (handily found at the top of every single documentation page).  Each part of the API is properly documented.  You have examples for the things without examples in the documentation.  You also have tips and notes and the documentation is detailed.  My only gripes?  Firstly, the main documentation set should be linking to the API documentation when they introduce or mention a specific API.  Secondly, I'd like to see a separate search facility explicitly for API calls so I don't have to hunt through the other documentation hits to get to the API documentation.

* In-browser debugging tools - 2/10. The team outsources their debugging tools to others.  I found a number of extensions for Chrome, Edge, and Firefox that purport to do the job, but none of them seemed to have much traction.  Maybe this isn't a problem?  It's nice to note that community members have stepped up to fix the problem, but it would be helpful to have something the team maintains.

* Official sample code - 4/10.  There is a lot of sample code sprinkled throughout the documentation, but there is no "official sample".  Instead, the docs point you to [awesome-mobx](https://github.com/mobxjs/awesome-mobx) which contains a lot of samples, including example projects that are endorsed by the MobX crew (and highlighted as such).  I enjoyed seeing how others used MobX and got a good number of tips from those examples.  However, it would be good to have official samples that show off how to do MobX with best practices that is documented as well.

* Community resources - 8/10.  MobX has been around for a while, which means there is a lot of material in the community - some good, some bad, and some that is just plain old.  The [awesome-mobx](https://github.com/mobxjs/awesome-mobx) site is a good resource.  You have videos, podcasts, blog posts, example code, discord, video training, and more.  It's more about sorting through what material is good and current vs. what material is bad or out of date.

At the end of the day, recommending this will depend on whether you get reactive programming.  It's a different mental model and you will either get it or you will struggle to understand it.  I like MobX as an alternative to Redux, but I think the overall experience of coding with Redux is better.

## Jotai - 52 points

Most state management libraries put application state in a large centralized store.  Atom-style libraries split the state store into multiple "atoms", which are basic data structures.  You can then use selectors to group related states together (as opposed to using selectors to slice the store for use).  I scratched my head on this until I understood the core documentation.  At least it wasn't as hard to understand as finite state machines.

* Developer experience - 6/10.  Developer experience is such a hard thing to define.  It's how things are named, but also how easy it is to understand what is going on so you can debug problems, and how easy it is to get to the right docs for the situation.  Once I got over the basic issue of terminology within this library (and figured out what atoms really were in my mind), I found this library relatively easy to work with.  As I got more into the library, though, I found myself relying on thinking "What will Jotai call this thing that I'm trying to do?" so I could effectively query the docs.  Unfortunately, I found myself expecting useAtom() to work like useState() - another React hook.  It's not so simple as that.  The experience was like skiing - easy to get started, but harder to make the jump to intermediate or expert.
  
* Integrations - 8/10.  Finally, a library that understands what it means to integrate!  There are integrations for all manner of caching and data fetching capabilities.  Each one has a dedicated page, with links to the integrated library and documentation with examples on how to use it.  Most of the integration documentation, however, relies on you knowing what the underlying library does.  For example, I took a look at "Optics", not knowing what the optics library does, and learned that focusAtom() creates a new atom based on a focus.  Hmmm - very informative - thanks!  I had to go to learn about optics library to understand if it would be helpful.  The extensions section of the docs would be better served being more prescriptive and saying "You want to do job X - here is the library / integration for you!"  Funnily enough, a lot of the integrations are with other state management libraries, making me think that Jotai is not intended for state management at all.

* Tutorial quality - 4/10.  They need to link [their tutorial](https://tutorial.jotai.org/quick-start/intro) somewhere in their documentation. The "introduction" page (where I would normally expect this to be) is just a set of links for keywords.  It does not help you get started.  The tutorial is only linked from the home page.  Once you get there, it's well written.  One nit - the tutorail doesn't let you click back to get back to the home page and doesn't have a home page link anywhere.

* Documentation quality (beginner) - 3/10.  Really, this library is not for the beginner at this point.  It's described as a drop-in replacement for useContext, but you have to dig through a lot of documentation to find the beginner stuff.  I ended up doing a search for beginner information (which is when I stumbled across their tutorial - which is well written).  Their documentation set just needs to be expanded and organized properly.

* Documentation quality (intermediate) - 5/10.  Like many other libraries, this is where the meat of the good stuff is.  Unlike many other libraries, there are assumptions made on the knowledge level of the reader.  This is really "documentation by and for the authors" and doesn't really care what you are trying to do.

* API documentation - 0/10.  There is no API documentation.  I guess they think the documentation they provide is enough.

* In-browser debugging tools - 8/10.  Jotai integrates with both React DevTools and Redux DevTools (with a little help from a plug-in) and it has its own devtools package.  The nice thing here - I didn't actually have to use any of the debugging tools in my trials (although I opened them up to see what happened).  I liked that I didn't have to install "yet another tool" to take advantage of debugging.

* Official sample code - 8/10.  The developers actually took the time to produce a number of samples.  The tutorial page has some nice and easy to understand tutorials, whereas the main documentation page has links to some more complex code samples.  Neither set is documented, so it's hard to follow along with the unfamiliar code base.

* Community resources - 4/10.  There are, of course, videos and blogs.  This is, at this point, to be expected.  Other than that, where is the content?  The first few pages of google search was the Jotai docs - not the community resources.  There is a discord channel and an X.com update feed, but that's what they call "community".

I like where this library is going, using its hooks semantics, minimal API philosophy, and acting as a replacement for useState and useContext.  However, I find myself preferring the "batteries included libraries", and it lacks organization for the docs, tutorials, and examples that would make it a widely adopted library.

## Recoil - 53 points

If [Jotai][jotai] tended towards minimalism, [Recoil][recoil] is the same thing with batteries included.  It uses the same "atoms" style that Jotai uses, but tends towards the kitchen sink approach that Redux uses.  I like it

* Developer experience - 7/10.  Once you get a handle on the core concepts (there are only two - atoms and selectors), this was a pleasure to work with.  Yes, it had an advantage coming after Jotai in my list - I didn't have to re-learn the concepts.  Things I liked - eslint integration, development tools, testing capabilities - and all were documented.  The author also made it clear where some things were not as "GA" as they could be.
  
* Integrations - 6/10.  Data fetching is done with a GraphQL connector via the Relay library.  Persistence is done through an "atom effect" that uses localStorage (and doesn't have its own library).  There is no integration with react-router, but there is an example of maintaining a history of changes which could be used with the history API.  I'd say this is less "batteries included" and more "we've given you the tools to be successful, but you get to do the work."

* Tutorial quality - 8/10.  The getting started tutorial is the age-old "Todo" app, and there is an interactive version, a non-interactive version, and a video course.  It was easy to follow and I had a working app at the end of it and understood the core concepts - ready for the next step of integrating it into my app.

* Documentation quality (beginner) - 4/10.  Unfortunately, the basic tutorial was all there was for beginner documentation.  Maybe that's enough, but I wanted a little more - maybe a walk through of data fetching, or expanding the todo app into preferences saving and persistence, maybe?  I felt the tutorial was too light.

* Documentation quality (intermediate) - 6/10.  There also wasn't a huge amount for intermediate developers.  The documentation set includes guides, but one of the guides is "Atom Effects".  I admit, I had to read that one just to find out what it was about.  There is a wealth of information there!  Unfortunately, bad organization and writing for the wrong audience means it's hard to use this documentation.  It's still better than some of the other libraries on this list though.

* API documentation - 9/10.  Absolutely astounding API documentation with full usage, examples, and great explanations.  Obviously, a lot of effort has been placed here - probably because the author needs the information.  My only gripe is that there isn't any cross-linkage between the base documentation and the API documentation, nor is there a dedicated search for the API documentation.

* In-browser debugging tools - 0/10.  The author has placed a whole section on "Dev Tools", but it's more code.  I would have expected to have *something* to show off in the debug section.  Since Recoil is React only, maybe a tab in the React Dev Tools.  Nothing was available.  This, unfortunately, makes diagnosing issues problematic.

* Official sample code - 0/10.  There are no examples in the GitHub repository, nor on the documentation site.  Fortunately, I found a few other example sites (thanks GeoffCox!), but they are sparse on details.

* Community resources - 6/10.  You have blogs, videos, video courses on the main sites (including freecodecamp, which is a bonus).  There are in-depth videos on the main site, and an active discussions section on the GitHub repository.  It would be nice(r) to see a community section on the main page of the repository, but there is an [awesome-recoil](https://github.com/nikhil-malviya/awesome-recoil) that doesn't seem to be maintained.

Overall, this was one of the nicer libraries to use.  I liked its focus on integrating with GraphQL and being "batteries included".  It still has a way to go to match MobX and Redux though.

## Valtio - 58.5 points

Valtio makes a bold statement - "self-aware proxy state" - something that really doesn't mean anything.  In the end, it's a reactive / observable style library.  

* Developer experience - 8/10.  I think the thing I liked about this library is that you don't need to understand a huge number of concepts to use it in an impactful way.  You just need to understand hooks.  The team switches between a "store" and a "proxy" interchangeably, so once I understood that the store was just the bigs of data I wanted (which is just like every other state management library), I was sailing along.  Developer experience ensures that developers are productive, and this library covers it nicely.  It also integrates with Redux DevTools, so I don't have to install additional stuff to see what's going on - it's already there.  Even the documentation has been thought about (although there are frictions there).  There is also an ESLint plugin that warns against common pitfalls.
  
* Integrations - 4/10.  There is a how-to section on how to persist state.  For data fetching and react-router, you are on your own.  Unfortunately, persistence is the easiest of the integrations I need and it took some time before I understood the best way to do data fetching.  At this point, I've given up on a react-router integration - no-one does it except for Redux.

* Tutorial quality - 7/10.  Page 1 of the guide has a "todo" app from beginning to end, with code sandboxes along the way and additional examples for you to investigate.  The presentation wasn't great (especially if you are using a lot of code sandboxes), but the content is solid.

* Documentation quality (beginner) - 4/10.  As with recoil, the authors decided that the tutorial / getting started experience was enoguh and you were all of a sudden experienced enough with the library.  The next section of the documentation takes leaps of cognitive ability, although they used the same code sandboxes to set up example code (which tend to break suddenly because of credits).  Some of these guides are needed for beginners (particularly the component state one) but they don't go into enough details for a beginner.

* Documentation quality (intermediate) - 6/10.  I love the broken out how to guides.  There are just not enough of them.  I wish there were how tos on how to integrate data fetching via REST and GraphQL, for example.

* API documentation - 7/10.  The authors have provided solid API documentation, but the examples included are in code sandboxes.  I found myself running out of credits to view the examples.  The examples should not rely on something that is paid for.

* In-browser debugging tools - 7/10.  There is a "devtools" plugin that allows you to view state in Redux DevTools.  You need to explicitly enable it with code, but that's way better than some of the other libraries where you have no visibility.

* Official sample code - 4/10.  The GitHub repository has a number of examples, but none of the them are in enough depth to actually teach you anything, nor does the author comment his code.  At least he has some examples!

* Community resources - 5/10.  There are the usual assortment of blogs and videos, a discord channel (shared with other react tech), and a couple of online courses (including one by the author).  It's average for a library in this space, really.

The author of this library seems to also do Jotai and Zustand, and prefers minimalism over batteries included.  He seems to have a version of state management irrespective of which style of library you prefer.  I think he is spreading himself too thin and solving problems for others instead of solving a problem he has.  It shows in the code, examples, documentation, and the overall feel of the libraries.  As with the others, I would be hard pressed to recommend this library.  That being said, I liked this version better than the others overall.

## useContext - 48.7

Finally, we come to the philosophy "what if we didn't have a library for state management?"  Do you really need one? The [`useContext()`][useContext] hook is a react hook that lets you read and subscribe to context from your component.  To use it, you have to use `createContext()`, then use the hook within your component to access the data and methods in the context.  The `createContext()` is then provided as a Provider component so that you wrap the entire application in it.

* Developer experience - 6/10.  There are only two methods to understand - both with the word "context" in them.  There is a common pattern to set up the provider component.  I dislike having to wrap my application multiple times (so I generally have a higher-order component that bundles providers).  Context is handily supported in the React Dev Tools extension, but it lacks some advanted features such as middleware and performance optimizations.  It's also not suitable for complex state maangement needs or frequent state updates since everything inside the Provider element re-renders when state changes.
  
* Integrations - 0/10.  There are no integrations.  This is the ultimate DIY implementation.  There is no persistence and no data fetching.  You have to do it yourself.

* Tutorial quality - 1/10.  There is a basic usage (a theme selector), but it doesn't result in a working application.  This is "just a feature of React", so they feel it doesn't need its own tutorial, I guess.

* Documentation quality (beginner) - 4/10.  The basic overview is great for understanding context, but you have to go elsewhere to understand the React Context API.  It's "good enough" documentation.

* Documentation quality (intermediate) - 6/10.  As with the beginner documentation, there isn't much here.  What is here is well written and focused on troubleshooting - which is good and important.

* API documentation - 5/10.  Yes, there is API documentation.  It's "good enough", but would do better to be integrated into the overall React APIs documentation (which is scattered across the doc set).

* In-browser debugging tools - 10/10. You can use React Dev Tools for this - it's built in.  This is actually a solid necessity for working with React, so no complaints here.

* Official sample code - 4/10.  There are plenty of samples with React.  They are not organized at all, and not one covers the context API.  That being said, there are plenty of samples from the community that DO cover the Context API.  I just wish there was a canonical example app.

* Community resources - 10/10.  This is part of React.  React has a fantastic and supportive community.  You really don't need to worry about not being able to get help or find information here.  This includes plenty of blogs, videos, free courses, paid courses, discords, discussion boards, and more.  Really, the only problem is that there is so much community, it gets overwhelming.

## Final thoughts

There was one library that I would term "not ready for prime time yet", and a whole slew of average libraries that would depend on your specific use case and how you mental model of state management corresponds to the implementation of the library.  Then there is Redux, which is still the de-facto state management library.

What would I recommend?

* For large or more complex applications, use [Redux Toolkit](https://redux-toolkit.js.org/) or [Mobx][mobx] depending on your mental model preference (reducers vs. observables).

* For smaller projects, use [useContext] - there is no need for complex libraries.

I'm also personally keeping an eye on [recoil] - I think that this has the best potential of the up-and-comer libraries that I've gone through here.

If you want to do your own weightings, check out the [Excel spreadsheet](/assets/images/2024/06/state-management-2024.xlsx) that I used for this post.

<!-- Links -->
[react-redux]: https://react-redux.js.org/
[zustand]: https://docs.pmnd.rs/zustand/getting-started/introduction
[xstate]: https://xstate.js.org/
[mobx]: https://mobx.js.org/README.html
[jotai]: https://jotai.org/
[recoil]: https://recoiljs.org/
[valtio]: https://valtio.pmnd.rs/
[useContext]: https://react.dev/reference/react/useContext
