---
title: "Kong disaster recovery"
date: 2023-04-04
draft: false
tags: [
   "Kong",
   "Kong Enterprise",
   "Disaster Recovery"
]
---

## What we want to cover

This is a short overview on a popular question I have gotten a lot by customers: how is disaster recovery designed with Kong (regardless if open source or Kong Enterprise)?

In fact there are two answers we will talk about - let's start with

## Infrastructure setup

As modern cloud native solution Kong is designed and usually also used with [IaC (infrastructure as code)](https://en.wikipedia.org/wiki/Infrastructure_as_code). So depending on the used automation system getting a fresh empty new system up&running should be as easy as (re)running those automation scripts.

Just some common examples we see the most (we are agnostic to the used tool):

- [Ansible](https://www.ansible.com/)
- [Terraform](https://www.terraform.io/)
- [ArgoCD](https://argo-cd.readthedocs.io/en/stable/)
- [Pulumi](https://www.pulumi.com/)
- [Helm (Kubernetes)](https://helm.sh/)
- ...

As Kong is extremely lightweight and has next to no dependencies (besides a database) it is very easy to get a new instance up&running. We are normally talking here about a few minutes max.

**If the Postgres database has not been part of the outage pointing your Kong cluster to the still running Postgres already got you fully recovered.**

If the database also got destroyed see below for the next step.

## Kong configuration

Now let's assume we have again a running fresh instance of Kong and it is empty. So we now want to recreate all runtime configurations (services, routes, plugins, consumers, ....).

Thanks to the fact that Kong is storing all its configuration in a Postgres database and can be configured declaratively we have multiple options to recover - each single one of them already serves our purpose - but many customers use two or all three for most flexibility, security and speed:

### Restore from database backup

If you have a backup of your database you can simply restore it and you are done. This is the easiest and fastest way if your database backup is current.

### Applying a declarative dump

With [decK](https://docs.konghq.com/deck/latest/) (declarative configuration of Kong) there is a command available to [dump the whole gateway configuration into YAML files](https://docs.konghq.com/deck/latest/reference/deck_dump/):

```bash
deck dump --all-workspaces
```

(`-all-workspaces` only needed on Kong Enterprise as open source has no RBAC)

This will create a folder structure with all the configuration files. Now you can simply [apply those files to your new instance of Kong](https://docs.konghq.com/deck/latest/reference/deck_sync/):

If you dumped a single workspace / are on open source:

```bash
deck sync -s myDumpFile.yaml
```

If you dumped multiple workspaces they are all in one folder. You can then apply all of them at once with:

```bash
deck sync -s /path/to/myDumpFolder
```

This approach obviously requires that you have a current deck dump available (most common automatically stored in your version control system).

### The wonder of CI/CD

This way is getting very common if you have already configured your Kong instance configuration completely with [CI/CD](https://en.wikipedia.org/wiki/CI/CD).

In such a scenario all runtime configurations are applied by CI/CD pipelines. So in case of a disaster you can simply **re-run your CI/CD pipelines and you are done**.

This last approach as said is becoming more and more common as you have those pipelines anyway and don't need to create dumps (regardless of database or deck) on a schedule. Also by nature this approach is incremental - any change to production is automatically applied to the next disaster recovery.

## Conclusion

Having worked with a lot of Enterprise software in my career ot still amazes me how simple and quick can be achieved with Kong - I remember on other systems (regardless if API Management or anything else) with the Enterprise tag in the name this normally was some kind of nightmare.

Personally my own demo system I have invented for Kong is fully based on those concepts - I can re-run a fresh demo environment for every presentation and infrastructure (as I do have IaC for different tech stacks).