---
title: "OpenAPI based schema validation on requests using Kong"
date: 2021-02-09
draft: false
tags: [
   "Kong",
   "Kong Enterprise",
   "OpenAPI",
   "JSON Schema"
]
---

**TL;DR**: just have a look at the last paragraph "All-in-one-go example"

## What are we talking about?

Ever since API gateways have been available there has been the use case to validate incoming requests against a schema. In the "good old times" of [SOA](https://en.wikipedia.org/wiki/Service-oriented_architecture)/[SOAP](https://en.wikipedia.org/wiki/SOAP)/[WSDL](https://en.wikipedia.org/wiki/Web_Services_Description_Language) the protocol itself was created from scratch with this being a use case so validating a SOAP request was very common.

In the world of [REST](https://en.wikipedia.org/wiki/Representational_state_transfer)/[JSON](https://en.wikipedia.org/wiki/JSON) the world has been much more agile with people just using this concept and only later such things as a schema were put on top. This would be fine if we nowadays would have one standard. But in real world we still have two - being close to each other but still not 100% compatible / feature rich.

As first we do have the winner of the REST API documentation wars from last decade where [WADL](https://en.wikipedia.org/wiki/Web_Application_Description_Language#:~:text=The%20Web%20Application%20Description%20Language,HTTP%20architecture%20of%20the%20Web.), [Blueprint](https://apiblueprint.org/), [RAML](https://en.wikipedia.org/wiki/RAML_(software)) and [Swagger](https://en.wikipedia.org/wiki/Swagger_(software)) have been the four major standards fighting for becoming the overall standard. Long story short (this could be an own and very long blog post...) the clear winner is Swagger - nowadays called [OpenAPI](https://en.wikipedia.org/wiki/OpenAPI_Specification). Only a few [Gallic villages](https://en.wikipedia.org/wiki/Asterix) are still using the "old" standards.

On the other hand we do have [JSON Schema](https://json-schema.org/) which has been more focused on describing - well, the name already tells us - a schema on a JSON object. This has been seen as the better language for validating requests as the standard is more powerful on this scenario.

Both of them a getting closer and closer (the end result should be a 100% JSON Schema compliant OpenAPI spec) but as of early 2021 we are not there yet. I don't want to put any "a is better than b" in this post - this is just a description of current state.

## Request validation in Kong Enterprise

When looking the [Kong Plugins hub](https://docs.konghq.com/hub/) we can spot an enterprise plugin called [Request Validator](https://docs.konghq.com/hub/kong-inc/request-validator/) which not only sounds promissing but out of the box solves our use case of request validation based on a JSON Schema.

Nevertheless a huge trend in the REST/JSON api economy is right now to put all configuration, validations and documentation in one single file - the OpenAPI description.

## Automation of Kong configuration in a declarative way

As you might know Kong has been created with automation as one of the major concepts - "[everything is an API](https://docs.konghq.com/enterprise/2.2.x/admin-api/)" has been a mantra ever since Kong has been released.

Looking at the current trends users of Kong are moving very fast from the interactive administration API to a declarative configuration based on YAML files.

Kong even has two options here - the Kubernetes Ingress rules as well as the [configuration using decK](https://docs.konghq.com/deck/). Great, so we now are able to configure only by using a YAML file like for example

```bash
deck sync --select-tag myCoolTag -s my-kong-yaml-file.yaml
```

Great - this tool also is able to apply plugins so we can use the Request Validator we have seen above and are done.

## OpenAPI in Kong to validate URLs and http methods

But now the major question: how do we generate this YAML file if we "only" have an OpenAPI specification? The answer is another great tool provided by Kong: [Insomnia](https://insomnia.rest/). Insomnia is known to many as being a great editor and testing tool for OpenAPI specs on the desktop and if you have attached the Kong Plugin Bundled it even comes with a button to export the OpenAPI as Kong YAML.

So we are very close - but didn't I speak about automation? So the great news is you can use the same functionality on the command line use the [cli version of Insomnia called inso](https://support.insomnia.rest/collection/105-inso-cli). 

```bash
inso generate config ./myOpenAPIspec.yaml -o my-kong-yaml-file.yaml
```

When you you then look into this file (or import it into Kong) you notice that the generated paths already only listen on specific urls like `/delay/(?<delay>\\S+)$` and also they are only listening on the http verb defined in the OpenAPI (like only GET requests for example).

```bash
http POST localhost:8000/delay/8 

HTTP/1.1 404 Not Found
(...)

{
    "message": "no Route matched with those values"
}
```

## But what about JSON Schema?

Great, we are very close - but there is one missing piece: how can we check the parameters of the call based on the OpenAPI? Let's assume we have an OpenAPI with this path:

```YAML
paths:
  /delay/{delay}:
    get:
      parameters:
        - in: path
          name: delay
          required: true
          schema:
            type: integer
            minimum: 0
            maximum: 10
          description: The delay in seconds
      responses:
        "200":
          description: Returns a delayed response
      summary: Returns a delayed response (max of 10 seconds).
      tags:
        - Delayed Response
```

So what do we see here? The GET request has a path parameter being an integer in a range of 0-10. So the last step is: how can we convert this information into a JSON Schema which is understood by the Request Validator plugin?

The answer can be found a little bit hidden in the [openapi-2-kong npm module](https://www.npmjs.com/package/openapi-2-kong) which is used under the hood by inso cli in the section on [Request Validation Plugin](https://www.npmjs.com/package/openapi-2-kong#request-validation-plugin): we only need to add the plugin without config to the operation(s) you want to check and JSON Schema is created automatically - so the OpenAPI like

```YAML
paths:
  /delay/{delay}:
    get:
      parameters:
        - in: path
          name: delay
          required: true
          schema:
            type: integer
            minimum: 0
            maximum: 10
 (....)
      x-kong-plugin-request-validator:
        enabled: true
```

So those two little lines at the end automatically enable the plugin and generate the JSON Schema for it. When looking at Kong the resulting schema being attached to the plugin looks like

```JSON
{
  "name":"delay",
  "style":"simple",
  "in":"path",
  "schema":"
    {\"type\":\"integer\",
    \"minimum\":0,
    \"maximum\":10}",
  "explode":false,
  "required":true
}
```

And a call to the endpoint with a wrong delay gets denied like

```bash
http GET localhost:8000/delay/11

HTTP/1.1 400 Bad Request
(....)
{
  "message": "request param doesn't conform to schema"
}
```

If you want to provide more info to your consumer also enable the setting `config.verbose_response=true` and the response looks like

```bash
http GET localhost:8000/delay/11

HTTP/1.1 400 Bad Request
(....)
{
  "message": "path 'delay' validation failed, [error] expected 11 to be smaller than 10"
}
```

Done :)

## All-in-one-go example

Find an example OpenAPI specification at <https://github.com/svenwal/uuid-generator-service/blob/main/uuid-generator.yaml> and you can use [inso cli](https://support.insomnia.rest/collection/105-inso-cli) and [decK](https://docs.konghq.com/deck/) like this:

```bash
$ inso generate config ./uuid-generator.yaml -o my-kong-yaml-file.yaml

$ deck sync --select-tag openapi-validated -s my-kong-yaml-file.yaml
```

You see a very long story but in the end extremely easy and perfect for automation.
