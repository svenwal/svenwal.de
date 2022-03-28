---
title: "Kong and the magic of routes"
date: 2022-03-28
draft: false
tags: [
   "Kong",
   "Kong Enterprise"
]
---

## What we want to cover

One of the most powerful but yet not well known feature of [Kong](https://konghq.com/) is the routes matching "magic". When you first start using Kong you get immediate success creating your first service and route when for example following the [Quickstart Guide](https://docs.konghq.com/gateway/latest/get-started/quickstart/configuring-a-service/). 

But there is so more to be told about. Everything we will discuss today is described at the [Proxy Reference](https://docs.konghq.com/gateway/latest/reference/proxy/#routes-and-matching-capabilities) but this part of the docs is not the first one when you starting reading the documentation.

## The longest path wins!

Let's start with a basic with two services and two routes.

```bash
http :8001/services name=service1 url=http://httpbin.org/anything
http :8001/services name=service2 url=https://jsonplaceholder.typicode.com/posts
http :8001/services/service1/routes paths=/myService -f
http :8001/services/service2/routes paths=/myService/posts -f
```

When we now try some calls to our proxy will notice that Kong validates per call what is the longest matching path:

`http :8000/myService` returns a response from httpbin.org

`http :8000/myService/posts` returns a response jsonplaceholder.typicode.com

`http :8000/myService/foo/bar` returns a response from httpbin.org

`http :8000/myService/posts/1` returns a response jsonplaceholder.typicode.com

So lesson one learned: even so they share the same prefix depending on the longest matching path different backends can be accessed. This can for example be used to expose multiple internal services (like in our example) to the outside would under the same root path which makes them feel as being one API.

This is something I sometimes call "orchestration light"

## 

So let's start with the certificate being served by Kong to the client (so the one you would see when opening the proxy in the browser).

### The default certificate

The default certificate presented by Kong after installation is a self-signed certificate. If you want to change this default copy your desired certificate and key on the machine and then set [ssl_cert](https://docs.konghq.com/enterprise/2.6.x/property-reference/#ssl_cert) and [ssl_cert_key](https://docs.konghq.com/enterprise/2.6.x/property-reference/#ssl_cert_key) in your `/etc/kong/kong.conf`.

### Certificate per route

But what if Kong is listening on different hostnames/[FQDN](https://en.wikipedia.org/wiki/Fully_qualified_domain_name) - in this case we need to have different certificates being presented depending on the route.

So when looking at the [route object](https://docs.konghq.com/enterprise/2.6.x/admin-api/#add-route) we notice the `hosts` parameter which we can use to limit the hosts being listened on and also the `snis` parameter (SNI stands for "[server name indication](https://en.wikipedia.org/wiki/Server_Name_Indication)"). So this is what we are looking for.

But how do we define a SNI and which certificates it shall use? Well, you might already have guessed it: there is an API for that: [SNI API endpoint](https://docs.konghq.com/enterprise/2.6.x/admin-api/#sni-object)

So now that know how to attach a SNI to a route - how do we actually add the certificate being needed for the SNI? Also here the answer is: there is an [API to upload a certificate](https://docs.konghq.com/enterprise/2.6.x/admin-api/#certificate-object).

So the order is actually the exact opposite of how we just went through it:

1. Upload the certificate
2. Create a SNI and link to the uploaded certificate
3. Create a route linking to the SNI

### Let's Encrypt

If you want to automate the whole process using [Let's Encrypt](https://letsencrypt.org/) have a look at the [ACME plugin](https://docs.konghq.com/hub/kong-inc/acme/) which integrates Kong with Let's Encrypt for creation and auto-updating of certificates.

## #2 mTLS for clients

While all the other documentation here is true for both Kong and Kong Enterprise mTLS is an Enterprise only plugin.

### Authentication

The [mTLS plugin](https://docs.konghq.com/hub/kong-inc/mtls-auth/) has one major parameter called `ca_certificates`. As the name already tells us we need to specify one or multiple CAs which we will use as the trust source - only incoming certificates having been created using those CAs will be trusted.

And similar to what we wrote above we need to have those CAs being uploaded in advance using the [ca_certificates API endpoint](https://docs.konghq.com/enterprise/2.6.x/admin-api/#ca-certificate-object).

### Authorization

So we have now authenticated the incoming certificate - but how do we now make sure not every issued certificate by the CA is allowed to make the call.

For this the [mTLS plugin](https://docs.konghq.com/hub/kong-inc/mtls-auth/) provides two paramters:

1. By default the parameter `skip_consumer_lookup` is set to false so there must be a matching consumer in Kong - if not consumer is found the call gets denied. If a consumer is found you can do all the typical consumer based steps - especially by adding the consumer to one or multiple groups by using the [ACL plugin](https://docs.konghq.com/hub/kong-inc/acl/)
2. Depending on the contents of your certificate it already might contain group membership information (see parameter `authenticated_group_by`) - if so those extracted groups can be directly used with the [ACL plugin](https://docs.konghq.com/hub/kong-inc/acl/) even without consumer matching in place.

## #3 Certificate presented by Kong to the upstream

Also the trust between the gateway and the backend system can be secured using certificates. This time Kong is in charge to present a certificate to the upstream to prove its identity.

### The default certificate

The default certificate presented by Kong after installation to the upstream is a self-signed certificate. If you want to change this default copy your desired certificate and key to the machine, enable [client_ssl](https://docs.konghq.com/enterprise/2.6.x/property-reference/#client_ssl) and then set [client_ssl_cert](https://docs.konghq.com/enterprise/2.6.x/property-reference/#client_ssl_cert) and [client_ssl_cert_key](https://docs.konghq.com/enterprise/2.6.x/property-reference/#client_ssl_cert_key) in your `/etc/kong/kong.conf`.

### Certificate per service

Sometimes you need to present different certificates to different upstreams so we can override the default certificate on a per-service-level.

So when looking at the [service object](https://docs.konghq.com/enterprise/2.6.x/admin-api/#service-object) we notice the `client_certificate` parameter which we can use to specify the to-be-presented certificate.

Similar to what we discussed above to the certificate into Kong see the [API to upload a certificate](https://docs.konghq.com/enterprise/2.6.x/admin-api/#certificate-object).

## Trusting the upstream's certificate

You can limit down the trusted certificates Kong is expecting from the upstreams - change the [lua_ssl_trusted_certificate](https://docs.konghq.com/enterprise/2.6.x/property-reference/#lua_ssl_trusted_certificate)
