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

But there is so much more to be told. Everything we will discuss today is described at the [Proxy Reference](https://docs.konghq.com/gateway/latest/reference/proxy/#routes-and-matching-capabilities) but this part of the docs  is not the first you look at when you start reading the documentation.

## The longest path wins!

Let's start with a basic with two services and two routes.

```bash
http :8001/services name=service1 url=http://httpbin.org/anything
http :8001/services name=service2 url=https://jsonplaceholder.typicode.com/posts
http :8001/services/service1/routes name=httpbin paths=/myService -f
http :8001/services/service2/routes name=jsonplaceholder paths=/myService/posts -f
```

When we now try some calls to our proxy will notice that Kong validates per call what is the longest matching path:

`http :8000/myService` returns a response from httpbin.org

`http :8000/myService/posts` returns a response jsonplaceholder.typicode.com

`http :8000/myService/foo/bar` returns a response from httpbin.org

`http :8000/myService/posts/1` returns a response jsonplaceholder.typicode.com

So lesson one learned: even so they share the same prefix `/myService` depending on the longest matching path different backends can be accessed. This can for example be used to expose multiple internal services (like in our example) to the outside would under the same root path which makes them feel as being one API.

## There is more than the path

Now that we have seen how different paths can be used to access different backends let's see what else can be used for differentiation. This all depends on which protocol you have chosen for the route - let's assume we are using the by far most used one which is http(s).

For http(s) the following matching criteria are available:

* paths
* hostname
* http verb / method
* headers
* SNI (https)
* http AND/OR https

So let's extend our previous example and say our `/myService/posts` route should send the `POST` requests to a different backend as we have optimized the read and write nodes in our cluster. We'll use our service1 now to serve those requests instead of service2:

```bash
http :8001/services/service1/routes name=post paths=/myService/posts methods=POST -f
```

You might notice that the `/myService/posts` path is the exact same one as we defined previously. So still all calls not being `POST` (like `GET`, `DELETE`, ...) are forwarded to the original backend but when someone makes a call as `POST` we suddenly have two paramters matching - `paths` AND `method` so this is a more specific route for this call and the other backend will be taken:

`http GET :8000/myService/posts` returns a response jsonplaceholder.typicode.com

`http POST :8000/myService/posts` returns a response from httpbin.org

## Regular expressions

Now let's get crazy and extremely flexible. If you have already read [Proxy Reference](https://docs.konghq.com/gateway/latest/reference/proxy/#routes-and-matching-capabilities) you might have noticed that the path of a route is a regular expression. So we can do very sophisticated differentiations now which includes input validation. Let's create a whole new route for our posts backend but this time we want:

1. should be available only on two languages 
2. should only work for posts with two digits post numbers

```bash
http :8001/services/service2/routes name=regexp paths=/(de|en)/myService/posts/[0-9]{2}$ methods=PATCH -f
```

Now we do some tests:

`http POST :8000/de/myService/posts/12` no match - wrong method `POST`

`http PATCH :8000/de/myService/posts/2` no match as we want exactly two digits

`http PATCH :8000/uk/myService/posts/12` no match as we provided the wrong country `uk`

`http PATCH :8000/de/myService/posts/12` match and we are getting a response wfrom the backend.

But wait - when looking a little bit more detailed into the response we notice now the backend has returned a `404` even so a post with the number 12 exists. This brings us to the last chapter

## What part is actually being forwarded to the backend?

