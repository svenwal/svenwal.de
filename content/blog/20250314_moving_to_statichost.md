---
title: "Moving from Netlify 🇺🇸 to statichost.eu 🇪🇺"
date: 2025-03-14
draft: false
tags: [
   "Hosting",
   "Europe"
]
---

## Goodbye 🇺🇸

It's sad to have to say this - but in the current circumstances relying on any hosting service being located in the United States of America is something you (I) want to avoid. I have been prefering local European services already in the past but some I still put on American servers - including all my blogs I have built based on [Hugo](https://gohugo.io/) which I used to host on Netlify. 

I now have moved all of them (see below) to the European provider [statichost.eu](https://www.statichost.eu/) - which was super easy as they are built automatically from the Git repos - for some more details see below.

The blogs and homepages I have moved away are:

- [svenwal.de (this page)](/)
- [exmo.travel (our page dedicated to our world travel tour)](https://exmo.travel)
- [bio.walther.world](https://bio.walther.world) and
- [www.gibts-doch-garnicht.de (very old German blog of mine)](https://www.gibts-doch-garnicht.de)

## How did the move happen?

First of all as [everything is in GitHub](https://github.com/svenwal/svenwal.de/tree/master) and Hugo already I could have moved on the spot - but took the opportunity to also update all of them to the latest Hugo versio (0.145) which sometimes included updaing some of the template files.

So on my local laptop I checked the repos out and using `hugo serve -D` tweaked them until they rendered locally as expected.

Next I created an account at [https://builder.statichost.eu/signup](https://builder.statichost.eu/signup) and started by adding site by site using their link to the GitHub repo Url (like https://github.com/svenwal/svenwal.de.git for this page here).

For the domain handling I created a a file called `statichost.yml` in the root of the repo ([see this one as example for this page](https://github.com/svenwal/svenwal.de/blob/master/statichost.yml)) which contains the [to be used Hugo version](https://www.statichost.eu/docs/ssg-guides/#hugo) (there is a [long list of options](https://docker.hugomods.com/choose/) - the `ci` one worked the best for me).

After the build works the final step was to [switch the DNS over from Netlify to statichost.eu](https://www.statichost.eu/docs/domains/) and boom here we are.

## Hint on build issues because of templates as git submodule

Ever since I have used automation for building with referencing an external template I had issues getting the local rendering in sync with the one from auto-generation. Based on some hint by the exceptional great support by statichost.eu (thanks Eric!) I moved over to [referencing them as Hugo module](https://github.com/theNewDynamic/gohugo-theme-ananke?tab=readme-ov-file#as-a-hugo-module-recommended) instead and since then everything works flawlessly.

## One more thing

Added the info about this also to the [README.md](https://github.com/svenwal/svenwal.de/blob/master/README.md) of every project including the badge if last export has completed.

[![statichost.eu status](https://builder.statichost.eu/svenwal-de/status.svg)](https://builder.statichost.eu/svenwal-de/)