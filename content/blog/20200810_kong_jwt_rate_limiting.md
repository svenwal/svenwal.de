---
title: "JWT claims and rate limiting with Kong Enterprise"
date: 2020-08-10
draft: false
tags: [
   "Kong",
   "Kong Enterprise",
   "OpenID Connect",
   "JWT",
   "Best practices",
   "Rate limiting"
]
---
## Rate limiting with Kong Enterprise
 
As everything in [Kong](https://konghq.com) and [Kong Enterprise](https://konghq.com/products/kong-enterprise), one can find many plugins which can be thought of as policies. In the case of rate limiting, Kong offers two  plugins:one that's  [open source](https://docs.konghq.com/hub/kong-inc/rate-limiting/) and another one that's [Enterprise only](https://docs.konghq.com/hub/kong-inc/rate-limiting-advanced/)) which you can use to limit the requests per caller, per route, per service and globally. Without going into too much detail here, you can apply them on a number of different levels [global, service, route and consumer](https://docs.konghq.com/2.1.x/admin-api/#precedence) to create a fine-grained setup on how many calls a consumer can make.
 
Today, we will talk about some of the more advanced use cases which can also be achieved, starting from [where we left off last time, discussing how to authorize calls using data originating from a JWT](/blog/20200128_kong_openid_connect_the_right_way/).
 
> :bulb: The following examples will be using the [Kong Enterprise Edition](https://docs.konghq.com/enterprise/) as this version includes the required [OpenID Connect](https://docs.konghq.com/hub/kong-inc/openid-connect/) and [Rate limiting Advanced](https://docs.konghq.com/hub/kong-inc/rate-limiting-advanced/) plugins
 
## Rate limit counter per consumer - without a Kong consumer
 
To begin,  we will recreate the entities we had in the other blog post. This means that we need to create  a service to a backend and a route where Kong will listen. This is done as shown below:
 
``` bash
http localhost:8001/services name=rate-limiting-jwt-service url=http://httpbin.org/anything
 
http -f localhost:8001/services/rate-limiting-jwt-service/routes name=rate-limiting-jwt paths=/rate-limiting-jwt
```
 
We can now test the endpoint in Kong by doing the following:
 
``` http
http://localhost:8000/rate-limiting-jwt
```
 
Now we need to attach once again the [openid-connect plugin](https://docs.konghq.com/hub/kong-inc/openid-connect/) to authenticate the end-user. However, this time, we won't require a specific scope:
 
``` bash
http -f localhost:8001/routes/rate-limiting-jwt/plugins \
     name=openid-connect \
     config.issuer=https://keycloak.apim.eu/auth/realms/kong/.well-known/openid-configuration \
     config.client_id=blog_post \
     config.client_secret=a5186adc-b5e2-4501-85a8-eb19a5e1a2a3 \
     config.ssl_verify=false \
     config.consumer_claim=email \
     config.verify_signature=false \
     config.upstream_headers_claims=email \
     config.upstream_headers_names=X-Kong-Extracted-User-ID \
     config.redirect_uri=http://localhost:8000/rate-limiting-jwt \
     config.consumer_optional=true
```
 
As our goal is to have a rate-limiting counter on a per user base **without** having to create them as a consumer within Kong, let's read a little bit on Kong's documentation for the [rate-limiting-advanced plugin](https://docs.konghq.com/hub/kong-inc/rate-limiting-advanced/) on how to accomplish this. It doesn't take long before we reach the following very important section:
 
| Form Parameter | Description |
|---|---|
| config.identifier optional default value: consumer | How to define the rate limit key. Can be ip, credential, consumer, service, or header. |
 
[Link to parameters section](https://docs.konghq.com/hub/kong-inc/rate-limiting-advanced/#parameters)
 
Within this section, one can find all of the options that Kong's plugin offers. Unfortunately, none seem to be a perfect fit. A good guess would be to use the parameter: "credential". Sadly, this wouldn't work as the tokens would be short-lived , which would mean that the credential would change again and again.
 
Still, there is one very interesting parameter in there - which is the option to use a header. If we would only happen to have a unique header per end-user, then everything would  work fine...mmm...
 
🥁 Drum roll...
 
Luckily, it turns out the OpenID Connect plugin provides the option to extract any claim(s) from the token and create headers based on that value.
 
The configuration parameters, [config.upstream_headers_claims](https://docs.konghq.com/hub/kong-inc/openid-connect/#configupstream_headers_claims) and [config.upstream_headers_names](https://docs.konghq.com/hub/kong-inc/openid-connect/#configupstream_headers_names) can help us accomplish what we need for our use case. The first will describe which claim(s) we want to export (as a comma-separated array) and the latter, defines how the name(s) of the created header(s) shall be.
 
If you now have a closer look at the Open ID Connect plugin configuration we have applied earlier in this blog post, you will notice I already placed those settings in:
 
``` bash
     (...)
     config.upstream_headers_claims=email \
     config.upstream_headers_names=X-Kong-Extracted-User-ID \
     (...)
```
 
Awesome! This means that we can now apply our rate-limiting plugin on the created route now and every user will get his own counter. This counter would then be used by the rate limiting plugin, based on the JWT token. Let's try this out.
 
We first need to set the rate limiting policy, as shown here:
 
``` bash
http -f localhost:8001/routes/rate-limiting-jwt/plugins \
     name=rate-limiting-advanced \
     config.identifier=header \
     config.header_name=X-Kong-Extracted-User-ID \
     config.window_size=60 \
     config.limit=5 \
     config.sync_rate=0
```
 
Now let's move on to KeyCloak. For testing purposes, I have created two example users in KeyCloak for us to use:
 
* blog_user1 / veryComplexPa55word
* blog_user2 / veryComplexPa55word
 
Now for the actual test, I would suggest that you open the URL in two different browsers (for example, Chrome and Firefox) and use one user per browser at http://localhost:8000/rate-limiting-jwt. This will help us guarantee that no cached tokens or sessions will interfere. On the response you will notice that our backend (httpbin.org) is incredibly helpful as it tells us which headers have been added so the response. Among the headers, you should find something like this: 
 
``` http
"X-Kong-Extracted-User-Id": "blog_user1@example.com"
```
 
## Can I have one counter for multiple end-users (like a whole company or department)?
 
The question above is one that I hear often, especially when my customer is hoping  to provide something like a budget to a customer or partner where multiple different people can use the API but they should all be counted against one global counter.
 
The solution to this, it's as simple as changing the setting from the OpenID Connect plugin from
 
``` bash
     (...)
     config.upstream_headers_claims=email \
     (...)
```
 
to
 
``` bash
     (...)
     config.upstream_headers_claims=groups \
     (...)
```
 
The change above allows us to now extract a unique group name instead of the end user's username. Yes, it would make more sense to provide a different name to the header like X-Extracted-Group or similar - but I think you get the point.
 
> :bulb: this is how my KeyCloak is set up - you obviously need to configure your IdP in a similar way to present the group claim somewhere in the token.
 
> :bulb: also notice this example setup depends on a user being in only one group as the groups claim otherwise might be something like group1,group2
 
## But what if I need a specific rate-limit for a specific consumer?
 
Well, the first observation to realize is that this per-consumer counter needs to be stored somewhere. To address this, we have two options:
 
### Rate limit defined per consumer
 
The above scenario works very well if all end-users have the same limit, but individual counters. And having such a default is what you typically want for the majority of your users.
 
So remember that we set the OpenID Connect plugin for the consumer being optional? The key word here is **"optional"**. This means that we still can create one for the exceptions!
 
``` bash
     config.consumer_optional=true
```
 
So if we create a consumer for example for our blog_user1@example.com and then we can attach our rate-limiting plugin to this consumer and as always the most specific settings wins. We will now have a different setting for this one consumer!
 
``` bash
http localhost:8001/consumers username=blog_user1@example.com
 
http localhost:8001/consumers/blog_user1@example.com/plugins \
     name=rate-limiting-advanced \
     config.identifier=consumer \
     config.window_size=60 \
     config.limit=50000 \
     config.sync_rate=0
```
 
### Rate limit defined by a JWT claim
 
This use case is another one that I hear from time to time, but not as often as the ones above. However, it is something that Kong will be able to do thanks to its flexibility and ability to add [custom logic](https://docs.konghq.com/latest/plugin-development/custom-logic/#plugins-execution-order) without a lot of effort. In order to address this specific use case, one can do this by following the instructions below:
 
1. Extract the claim where you let your IdP inject the limit into the token using the openid-connect plugin (as we did with the username above)
2. Change the plugin code limit detection to use this added header. You would change for example the line https://github.com/Kong/kong/blob/master/kong/plugins/rate-limiting/handler.lua#L123 in the rate-limiting plugin from
 
``` Lua
minute = conf.minute,
```
 
to
 
``` Lua
minute = kong.request.get_header("X-My-Extracted-Limit-Claim"),
```
 

