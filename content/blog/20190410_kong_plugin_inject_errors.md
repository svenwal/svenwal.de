---
title: "New Kong Plugin: Inject Errors"
date: 2019-04-10
draft: false
tags: [
    "Kong",
    "Plugins",
    "Lua",
    "Chaos Engineering",
    "Open Source"
]
---
As some of you might know already I have joined the awesome API Gateway vendor [Kong](https://konghq.com) this year. You have to check out our [open source lightweight and ultra-fast API gateway](https://github.com/kong) when you are somewhere in the API Management / Microservices / Service Mesh space.

But this shall not be about advertising Kong, this is about my first own from-scratch-plugin for Kong. I have been wondering how hard can it be to create an own plugin with no prior [Lua](https://www.lua.org) knowledge and the answer is: [it's really easy](https://docs.konghq.com/0.13.x/plugin-development/).

The idea is something I have heard recently at the [Berlin Kubernetes Meetup](https://www.meetup.com/de-DE/Berlin-Kubernetes-Meetup/): when developing both a microservices infrastructure as well as creating clients you cannot trust the network and the API backends at all. You must be aware of high latencies and backends failing with errors everywhere and you need to test it.

So if we use Kong in our infrastructure (regardless if as [traditional gateway](https://konghq.com/install/), as [ingress controller](https://github.com/Kong/kubernetes-ingress-controller) or as [sidecar](https://github.com/Kong/kubernetes-sidecar-injector)) wouldn't it be nice to inject some random latency and/or errors to you services? Due to the nature of Kong's plugin depyloment you can even choose to add them for [everything (global), per backend (service), per incoming URL (route) or per consumer](https://docs.konghq.com/1.1.x/admin-api/#precedence).

So this is what we have now: my new plugin ["Inject Errors"](https://github.com/svenwal/kong-plugin-inject-errors) is able to inject a random latency (you define minimum and maximum) at random calls (you define the percentage of all calls) as well as errors (once again you can define the percentage of calls and a list of http status calls).

You can find the plugin at my [GitHub repository](https://github.com/svenwal/kong-plugin-inject-errors) incl. the [LuaRock file](https://github.com/svenwal/kong-plugin-inject-errors/releases) for easy installation. It has been designed to be compatible with both the latest open source version of Kong (1.1.1) as well as latest Enterprise version (0.34.1).

---
From the GitHub readme:

# About
inject-errors is a [Kong](https://konghq.com) plugin which adds a random latency and/or random errors to responses in order to simulate bad networks.

## Configuration parameters
|FORM PARAMETER|DEFAULT|DESCRIPTION|
|:----|:------:|------:|
|config.minimum_latency_msec|0|This parameter describes the minimum latency (msec) to be added|
|config.maximum_latency_msec|1000|This parameter describes the maximum latency (msec) to be added|
|config.percentage_latency|50|Percentage of requests which shall get the latency added|
|config.percentage_error|0|Percentage of requests which shall return an error|
|config.status_codes|500|Array of http status codes which will be used if error is returned (random selection from array)|
|config.add_header|true|If set to true a header X-Kong-Latency-Injected will be added with either the value of the added latency or none if random generator has chosen not to add a latency. Also adds the X-Kong-Error-Injected header if http status code has been added.|

## Examples
`````
> http :8001/services/<SERVICE>/plugins name=inject-errors 

HTTP/1.1 201 Created
(...)

{
    "config": {
        "add_header": true,
        "maximum_latency_msec": 1000,
        "minimum_latency_msec": 0,
        "percentage_error": 0,
        "percentage_latency": 50
    },
    "created_at": 1554887400000,
    "enabled": true,
    "id": "1a659088-2e38-4a9f-bfef-f84400c86f5a",
    "name": "inject-errors",
    "route_id": "f42acc5b-4e85-4ec2-8638-c7dbdd84b8a9"
}
`````
Response if random generator has decided to add latency:
`````
> http :8000/latency

HTTP/1.1 200 OK
(...)
X-Kong-Proxy-Latency: 90
X-Kong-Latency-Injected:: 89
X-Kong-Upstream-Latency: 227

(BODY OF RESPONSE)
`````
Response if random generator decided not to add latency (see "none" in header)
`````
> http :8000/latency

HTTP/1.1 200 OK
(...)
X-Kong-Proxy-Latency: 1
X-Kong-Latency-Injected:: none
X-Kong-Upstream-Latency: 213

(BODY OF RESPONSE)
`````
Response with both latency and status code (400) injected (headers activated)
`````
HTTP/1.1 400 Bad Request
Connection: close
(...)
X-Kong-Error-Injected: 400
X-Kong-Latency-Injected: 276

Bad request
`````