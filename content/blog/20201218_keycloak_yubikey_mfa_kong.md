---
title: "Keycloak on Docker using Let's Encrypt with Yubikey as MFA and Kong Enterprise"
date: 2020-12-18
draft: false
tags: [
   "Kong",
   "Kong Enterprise",
   "OpenID Connect",
   "Keycloak",
   "Yubikey",
   "Touch ID",
   "MFA",
   "Docker",
   "WebAuthn",
   "Let's Encrypt"
]
---
## What we want to achieve

Authentication in a secure way has been important ever since but is becoming even more important every day. Having a [multi-factor-authentication](https://en.wikipedia.org/wiki/Multi-factor_authentication) is seen as the most secure way and becomes mandatory by more and more services (for example in European banking with  ["Strong Customer Authentication"](https://en.wikipedia.org/wiki/Strong_customer_authentication)).

Having a hardware token (like [Yubikey](https://en.wikipedia.org/wiki/YubiKey) in my example - but this also works exactly the same with for example [Touch ID by Apple](https://en.wikipedia.org/wiki/Touch_ID)) is the golden standard and we want to achieve this level of security using [Keycloak](https://www.keycloak.org/) today.

## Setting up Keycloak on Docker (docker-compose)

### Initial setup

Setting up Keycloak is really easy - just get a docker-compose file from [the official repository](https://github.com/keycloak/keycloak-containers/tree/master/docker-compose-examples).

### Let's Encrypt

But if we want to use it with a [WebAuthn](https://webauthn.io/) hardware token we need to make it listen on https. And while doing so we do not want to have a self signed certificate but instead use a certificate by Let's Encrypt.

Let's imagine you have already gotten your certificate and private key (see [Certbot](https://certbot.eff.org/)) - now we want to make our Keycloak using those files. I can tell you I have read and tried so many tutorials (invoking `keytool`, converting types, ...) while in the end it is very easy - if you know about the permissions. So all credits to [to this answer on stackoverflow](https://stackoverflow.com/a/61902931).

My docker-compose gets the following additions:

```YAML
  volumes:
    - ./certs/privkey.pem:/etc/x509/https/tls.key
    - ./certs/fullchain.pem:/etc/x509/https/tls.crt
  KEYCLOAK_HOSTNAME: my.own.hostname
```

! Make sure the **permissions on the privkey.pem are at 655**  when starting the containers !

## WebAuthn in Keycloak (Yubikey, Apple Touch ID, ...)

Next step is to configure your Keycloak to have WebAuthn enabled. As this is a process with many steps I do not want to copy&paste all the steps in here but instead ask you to read [this blog post by James which is a great step-by-step guide](https://blog.jimbob.net/2020/05/getting-with-webauthn-flow.html)

In the end you will have a Realm in Keycloak where you can register new users and each of them is forced to attach his security token / device. I have followed it and it works both with my various Yubikey's and with Touch ID on my 2018 MacBook Pro.

Note: Did my tests on current [Google Chrome](https://www.google.com/chrome/) and [Vivaldi](https://vivaldi.com/), other browsers may vary.

## Using it with Kong Enterprise

Now that we have a Keycloak with WebAuthn enabled - how can we use it with [Kong Enterprise](https://konghq.com/products/kong-enterprise) (Enterprise only as we are using the [OpenID Connect](https://docs.konghq.com/hub/kong-inc/openid-connect/) plugin)?

As you might remember from previous blog posts like [Using OpenID Connect the right way with Kong Enterprise](/blog/20200128_kong_openid_connect_the_right_way/) and [JWT claims and rate limiting with Kong Enterprise](/blog/20200810_kong_jwt_rate_limiting.md/) the OpenID Connect plugin has many, many powerful options - for our authentication use case this can be summed in:

1. Have a [client application in Keycloak](https://www.keycloak.org/docs/latest/server_admin/#_clients) configured with valid redirect URI(s) pointing back to your route in Kong (or for testing to "*" - not in production of course)
2. Create a service, a route and attach the OpenID Connect plugin. The only needed parameters are:

``` text
config.issuer = https://my.own.hostname:8443/auth/realms/MY_REALM_NAME/.well-known/openid-configuration
config.client_id = id of the client created in 1.
config.client_secret = secret of the client created in 1.
config.consumer_optional = true
```

Consumer optional being true so we can use any user in Keycloak without the need to also have a consumer with same username being in registered in Kong - see [my previous blog post](/blog/20200128_kong_openid_connect_the_right_way/) about this.

The following example calls (using [httpie](https://httpie.io/)) will create those settings for you in Kong - but be sure to change the URL in issuer as well as client_id and client_secret to your Keycloak.

``` bash
http localhost:8001/services name=oidc-mfa url=http://httpbin.org/anything
 
http -f localhost:8001/services/oidc-mfa/routes name=oidc-mfa paths=/mfa

http -f localhost:8001/routes/oidc-mfa/plugins \
     name=openid-connect \
     config.issuer=https://my.own.hostname:8443/auth/realms/MY_REALM_NAME/.well-known/openid-configuration \
     config.client_id=YOUR_CREATED_CLIENT_ID \
     config.client_secret=YOUR_CREATED_CLIENT_SECRET \
     config.consumer_optional=true
```

And that's it. As you can imagine there are even more use cases you can achive using this stack - for example the [consent handling](https://www.keycloak.org/docs/latest/authorization_services/#_service_user_managed_access) might be one of the those. I might create another blog post...?
