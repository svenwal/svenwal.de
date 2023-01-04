---
title: "My new VPN setup on Oracle Cloud"
date: 2023-01-04
draft: false
tags: [
   "VPN",
   "Wireguard",
   "Oracle Cloud",
   "Pi-hole"
]
---

## Why Oracle Cloud?

The setup I am going to describe has been working on my dedicated server for some time without any problems. But last year I have decided to decided to reduce my costs and consolidate my dedicated servers (three of them) to only one to save costs and complexity (giving up some fail-over scenarios).

While doing so the dedicated server who served my VPN was cancelled by me and I moved the majority of the hosted services to my main machine. But as this machine hosts some kind of critical services I did not want to add high traffic (VPN) and a custom DNS setup (PiHole) to it. So I decided to move the VPN [Oracle Cloud](https://www.oracle.com/cloud/).

So why Oracle? I do use in my professional life a lot of [AWS](https://aws.amazon.com/de/), [GCloud](https://cloud.google.com/) and [Azure](https://azure.microsoft.com/en-us/) but I have not much used Oracle Cloud. And there is a very interesting [always free tier](https://www.oracle.com/cloud/free/) available...

![Oracle Cloud free tier](/img/oracle_free_tier.png)

## Getting the Oracle instance

Well, this normally would not be an own chapter - but it turns out it needs to be one.

First I registered with Oracle Cloud and got the free tier. Nothing special about this with the exception that everything felt a little bit overcomplicated / dated.

Next I wanted to create a new instance. And this instance I wanted to max out the free tier while also using state-of-the-art technology - an ARM based server. The free tier includes one instance (or you could even split the hardware) with 4 cores and 24 GB of RAM - plenty of ressources for my VPN and the to-be-installed playgrounds and pet projects (there will be a Kong instance on that machine for sure).

And here starts the trouble - yes, this config is available in the free tier - but no hardware in the Frankfurt AD available (everytime I tried to create the instance I got the message no ressources could be allocated and I shall come back later). I started to try to get my instance on 2022-12-12 and it took me many, many tries until 2023-01-03 to finally get the instance up and running. Isn't one of the benefits of the cloud I don't need to worry about the hardware being available...?

![My instance hardware overview](/img/oracle_cloud_arm.png)

## Setting up Wireguard

There are many tutorials out there how to setup [Wireguard](https://www.wireguard.com/) on a Linux machine. I decided to go (again) with my Docker based setup which I copied over from my old dedicated server. I had to change nothing and got my Wireguard restored in a few minutes.

By nothing I mean I have pointed my DNS wireguard.my.domain.example.com to the new IP of my Oracle instance.

I am using [WireGuard Easy](https://github.com/WeeJeWel/wg-easy) with docker-compose and this is my configuration:

```yaml
version: "3.3"
services:
  wg-easy:
    environment:
      - WG_HOST=wireguard.my.domain.example.com
      - PASSWORD=xxxx
      - WG_DEFAULT_DNS=172.19.0.2
      # this is my PiHole in the Docker vpn network
      
    image: weejewel/wg-easy
    container_name: wg-easy
    volumes:
      - ./config:/etc/wireguard
    ports:
      - "51820:51820/udp"
      - "127.0.0.1:51821:51821/tcp"
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
networks: 
  default: 
    external: 
      name: vpn
```

Now a `docker compose up -d` brought up the Wireguard server and after I opened the port in the Oracle Cloud firewall I could connect to it with my Wireguard clients. As I have also copied the config directory (see volumes in above YAML) all settings and clients were restored.

![WireGuard overview](/img/WireGuard.png)

## Pi-hole

I am using [Pi-hole](https://pi-hole.net/) at my home  for many years and it always shocks me when using "normal internet" (like my cell phone) how much s**t is loaded without it. The internet is doomed due to marketing and sales guys... :(

So I wanted to have Pi-hole also in my VPN so I can use the internet everywhere without all this bloated crap. And long story short: I have also used docker-compose for this and copied the config over, started it and it  works perfectly.

```yaml
services:
  pihole:
    container_name: pihole
    image: pihole/pihole:latest
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "67:67/udp"
      - "127.0.0.1:8067:80/tcp"
    environment:
      TZ: 'Europe/Berlin'
      WEBPASSWORD: xxxxx
    volumes:
      - './etc-pihole:/etc/pihole'
      - './etc-dnsmasq.d:/etc/dnsmasq.d'
    restart: unless-stopped
networks: 
  default: 
    external: 
      name: vpn
```

## Conclusion

The move from the dedicated server to the Oracle Cloud was extremely easy - thanks to Docker and the mounted configuration directories I only needed to copy those folders, open the firewall and done.

But Oracle Cloud did not have a good start for me - the user interface and the lack of available hardware have been disappointing so far. But I hope this will improve over time.