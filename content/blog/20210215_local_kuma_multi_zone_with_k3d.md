---
title: "Creating a local multi-zone Kuma / Kong Mesh Kubernetes cluster"
date: 2021-02-09
draft: true
tags: [
   "Kong Mesh",
   "Kuma",
   "Multi Zone",
   "k3d"
]
---

## What are we talking about?

When it comes to service mesh the need for having a mesh spanning multiple different environments (different deployment zone, different clouds, on-premise, ...) is becoming a critical functionality and [Kuma](https://kuma.io/) is the mesh which has been [designed for multi-zone deployments from the very beginning](https://kuma.io/docs/1.0.7/documentation/deployments/#multi-zone-mode).

Now that we solved this we have another first world problem: how can we test such a scenario without the need to spin up multiple (expensive) Kubernetes instances in the cloud(s)?

## Prerequisites

As we want to install multiple Kubernetes instances in parallel on our local machine we need them to be lightweight and fast. So the first thing we need to be installed is [K3d](https://k3d.io/) - a very lightweight Kubernetes installation based on [k3s](https://github.com/k3s-io/k3s) running within your Docker.

Next thing is we need to have Kuma installed - or to be more correct we need the [kumactl](https://kuma.io/docs/1.0.7/documentation/cli/) client. As you can see [at the documentation](https://kuma.io/docs/1.0.7/installation/kubernetes/#_1-download-kuma) the installation is very easy 

```bash
curl -L https://kuma.io/installer.sh | sh -
```

I would recommend to add the Kuma bin folder into your PATH for convenience (and my below scripts expects it ;))

## Spinning up the clusters

I have created a script which spins up three instances of k3d, installing in the first cluster the global control plane and into the other two remote control planes.