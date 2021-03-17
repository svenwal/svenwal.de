---
title: "Getting Kong Manager to work (and also Kong Developer Portal)"
date: 2021-03-16
draft: false
tags: [
   "Kong",
   "Kong Enterprise",
   "Kong Manager",
   "Developer Portal",
   "Sessions"
]
---

TL;DR: If your Kong Manager is not working check the settings of `KONG_ADMIN_API_URI` and `KONG_ADMIN_GUI_URL`.

## The Kong Manager

Since February 2021 the [Kong Manager](https://docs.konghq.com/enterprise/2.3.x/kong-manager/overview/) (which has been a Kong Enterprise feature for many years) has become part of the free version of Kong.

As I have been working with the Kong Manager for a long time and having helped many users in getting it set up correctly I want to share the typical configuration issues I have seen.

## Works out of the box

First of all I have to say that Kong Manager works out of the box. Smoothly install Kong (Free or Enterprise) on your local machine, enable it and it will be working fine on <http://localhost:8002> as expected.

![Kong Manager on localhost](/img/Kong_Manager_localhost.jpeg)

![Kong Manager on localhost diagram](/img/Kong_Manager_diagram_localhost.jpeg)

## How it breaks (and how to fix)

In real world installation you don't want to have the Kong Manager on a random local machine but instead have it installed on a server and access it using a nice DNS entry. And while doing so you don't want to have ports like 8002 but instead use different hostnames.

![Kong Manager behind load balanver](/img/Kong_Manager_behind_loadbalancer.jpeg)

So let's assume you have put your Kong installation behind a LoadBalancer/Ingress/... and are now exposing the original <http://localhost:8002> on a nice hostname like <https://kong-manager.my-company.example.com>. When you open this you will get a Kong Manager but the default workspace is gone and and the button to create a new workspace does not work. So what has happened?

![Kong Manager not working](/img/Kong_Manager_broken.jpeg)

As you might be well aware everything in Kong is an API and so the whole Kong Manager user interface is a browser based application running in your local browser. And if you have not changed any configuration it will now start to make calls to the default Admin-API address which is <http://localhost:8001>.

As Kong cannot know how the external URL of the Admin-API is we have to specify it in the configuration. Let's say you have now mapped the 8001-Port to something like <https://kong-admin.my-company.example.com> then you will need to set

```config
admin_api_uri = https://kong-admin.my-company.example.com
```

or (if you are using environment variables)

```config
KONG_ADMIN_API_URI = https://kong-admin.my-company.example.com
```

Much better, now your browser knows where to find the admin API and will start making calls to it. But if you try it the result will be still bad - it does not work. So what are we missing?

We have been so nice and created different hostnames for the Manager and the Admin API but this triggers now the CORS protection of our browser - the JavaScript on <https://kong-manager.my-company.example.com> tries to make a call to <https://kong-admin.my-company.example.com> and your browser will deny it (because of cross-origin). So as a second step we need to make sure the Admin-API is sending a correct Allow-Origin-Header. To do so we need to tell Kong now how the URL of the Kong Manager is:

```config
admin_gui_url = https://kong-manager.my-company.example.com
```

or (if you are using environment variables)

```config
KONG_ADMIN_GUI_URL = https://kong-manager.my-company.example.com
```

![Kong Manager behind load balanver](/img/Kong_Manager_behind_loadbalancer.jpeg)

And now it works.

![Kong Manager working](/img/Kong_Manager_working.jpeg)

## Enabling RBAC and logging in not possible

When using Kong Enterprise you typically want to secure your Admin-API and the Kong Manager using [RBAC](https://docs.konghq.com/enterprise/2.3.x/kong-manager/authentication/super-admin/). Let's assume you have set everything up for `basic-auth` and the `Kong-Admin-Token`-header works fine on the admin API. But when opening the browser and logging in there (hint: the standard username is `kong_admin` if you have set the password during bootstrap) it does not work.

Given our example from above what happens now is that the login itself works fine - only the created session cookie is not valid for both domains (you log in at <https://kong-manager.my-company.example.com> and the cookie will only be valid for the UI - not the Admin-API).

In order to make this cookie being accepted on both DNS names by your browser we need to configure it to be valid on both DNS entries.

```config
admin_gui_session_conf = {"cookie_domain":"my-company.example.com","secret":"your-random-secret","cookie_secure":false}
```

or (if you are using environment variables)

```config
KONG_ADMIN_GUI_SESSION_CONF = {"cookie_domain":"my-company.example.com","secret":"your-random-secret","cookie_secure":false}
```

The important part here is in `cookie_domain` which needs to be set to the subdomain both of your URLs have in common - in our example `my-company.example.com` is shared by both URLs.

Hint: I have also added `cookie_secure` to this example even so you won't need it as I have assumed you are exposing Kong using `https`. Only wanted to have it here in case you are exposing Kong with `http` only.

## Developer Portal

Now that we have learned a lot about major principles for those API based user interfaces we can be very quick with the [developer portal](https://docs.konghq.com/enterprise/2.3.x/developer-portal/) as it shares the accept same principles (a web based user interface and an API) so we have to do similar things to get this to work:

```config
portal_gui_protocol = https
portal_gui_host = kong-portal.my-company.example.com
portal_api_url = https://kong-portal-api.my-company.example.com
kong_portal_session_conf = {"cookie_name":"portal_session","secret":"another-random-secret","cookie_secure":false,"cookie_domain":"my-company.example.com"} 
```

or (if you are using environment variables)

```config
KONG_PORTAL_GUI_PROTOCOL = https
KONG_PORTAL_GUI_HOST = kong-portal.my-company.example.com
KONG_PORTAL_API_URL = https://kong-portal-api.my-company.example.com
KONG_PORTAL_SESSION_CONF = {"cookie_name":"portal_session","secret":"another-random-secret","cookie_secure":false,"cookie_domain":"my-company.example.com"} 
```
