---
title: "Kong and the magic of routes"
date: 2022-04-05
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
http :8001/services name='service1' url='http://httpbin.org/anything'
http :8001/services name='service2' url='https://jsonplaceholder.typicode.com/posts'
http :8001/services/service1/routes name='httpbin' paths='/myService' -f
http :8001/services/service2/routes name='jsonplaceholder' paths='/myService/posts' -f
```

When we now try some calls to our proxy will notice that Kong validates per call what is the longest matching path:

`http :8000/myService` returns a response from httpbin.org

`http :8000/myService/posts` returns a response jsonplaceholder.typicode.com

`http :8000/myService/foo/bar` returns a response from httpbin.org

`http :8000/myService/posts/1` returns a response jsonplaceholder.typicode.com

![Path matchings](/img/PathMatching.png)

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
http :8001/services/service1/routes name='post' paths='/myService/posts' methods='POST' -f
```

You might notice that the `/myService/posts` path is the exact same one as we defined previously. So still all calls not being `POST` (like `GET`, `DELETE`, ...) are forwarded to the original backend but when someone makes a call as `POST` we suddenly have two paramters matching - `paths` AND `method` so this is a more specific route for this call and the other backend will be taken:

`http GET :8000/myService/posts` returns a response jsonplaceholder.typicode.com

`http POST :8000/myService/posts` returns a response from httpbin.org

![Path matchings](/img/HttpVerbMatching.png)

## Regular expressions

Now let's get crazy and extremely flexible. If you have already read [Proxy Reference](https://docs.konghq.com/gateway/latest/reference/proxy/#routes-and-matching-capabilities) you might have noticed that the path of a route is a regular expression. So we can do very sophisticated differentiations now which includes input validation. Let's create a whole new route for our posts backend but this time we want:

1. should be available only on two languages 
2. should only work for posts with two digits post numbers

```bash
http :8001/services/service2/routes name='regexp' paths='/(de|en)/myService/posts/[0-9]{2}$' methods=PATCH -f
```

Now we do some tests:

`http POST :8000/de/myService/posts/12` no match - wrong method `POST`

`http PATCH :8000/de/myService/posts/2` no match as we want exactly two digits

`http PATCH :8000/uk/myService/posts/12` no match as we provided the wrong country `uk`

`http PATCH :8000/de/myService/posts/12` match and we are getting a response wfrom the backend.

But wait - when looking a little bit more detailed into the response we notice now the backend has returned a `404` even so a post with the number 12 exists. This brings us to the last chapter

## What part is actually being forwarded to the backend?

When it comes to the question what the backend actually sees from the request`s route incoming the answer is: whatever is followed to the matching path<sup>*</sup>.

So when we look into the first examples above the request 

`http :8000/myService/foo/bar` is being forwarded to `http://httpbin.org/anything/foo/bar` and 

`http :8000/myService/posts/1` is being forwarded to `https://jsonplaceholder.typicode.com/posts/1`

This explaines what has happened when we created our regular expression route above with `/(de|en)/myService/posts/[0-9]{2}$` - the `12` we have used as a parameter itself is part of the match and because of this not forwarded the backend.

In order to get also this part of the path being sent to the backend we have to do two things:

1. Change our route to extract the number we want to forward

```bash
http PATCH :8001/routes/regexp paths='/(de|en)/myService/posts/(?<post_id>[0-9]{2})$' -f
```

2. Use the just extracted `post_id` and include it in the path by applying the [Route Transformer Advanced Plugin](https://docs.konghq.com/hub/kong-inc/route-transformer-advanced/)

```bash
http POST :8001/routes/regexp/plugins name='route-transformer-advanced' config.path='/posts/$["uri_captures.post_id-name"])' -f
```

When we try now again `http PATCH :8000/de/myService/posts/12` we are now getting forwarded to https://jsonplaceholder.typicode.com/posts/12 (we are seeing a `200` as response) and could change the entry (as we are making a `PATCH` request)

Note: we also have to include the `/posts` as the transformer rewrites the whole path - including the one specified at service level!

![Route transformer](/img/RouteTransformer.png)

\* this is controlled by the parameter [strip_path](https://docs.konghq.com/gateway/latest/admin-api/#request-body-3) which is set to `true` by default - with the important exception in the [Kong Ingress Controller](https://docs.konghq.com/kubernetes-ingress-controller/2.3.x/references/annotations/#konghqcomstrip-path)

## Download this example

The whole example can be downloaded (and then imported) from [this decK dump](https://github.com/svenwal/svenwal.de/tree/master/static/misc/route_matching_deck_dump.yaml)
