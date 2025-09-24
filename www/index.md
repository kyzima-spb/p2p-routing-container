> **Не работает! Ведется работа по полному обновлению контейнера**

Router
======

- [Introduction](#introduction)
  - [Non-standard Routing Method](#non-standard-routing-method)
- [How to install a container?](#how-to-install-a-container)
- [How to uninstall a container?](#how-to-uninstall-a-container)
- [How to Choose the Right VPS?](#how-to-choose-the-right-vps)
  - [Minimum System Requirements for Choosing a VPS](#minimum-system-requirements-for-choosing-a-vps)
  - [What I Used and Can Recommend](#what-i-used-and-can-recommend)

## Disclaimer

> If you arrived at this page via one of the links to AntiZapret, don’t be surprised — this used to be it =)
> 
> I liked the idea of targeted routing implemented in this container,
> but the container itself became outdated N years ago.
> 
> I used it as the basis for my own container, ambitiously named **nspawn-router**,
> rewrote it with an up-to-date stack, added the functionality I needed, and removed AntiZapret.
> 
> Now this container can be used to organize routing for your own purposes.
> The core still relies on the combination of `OpenVPN + Knot Resolver + nftables + dnsmap`.
> 
> [Read more about VPN technology](#about-vpn-technology) and its connection to restricted services.
> 
> **The container author is not responsible for how or by whom this container will be used!**

## Introduction

**nspawn-router** - a containerized solution for organizing traffic routing.
It allows you to isolate network flows, direct them through specified interfaces or tunnels,
and use the container as an intermediate router/filter without involving the host system.

### Non-standard Routing Method

The container uses domain name–based routing via a dedicated DNS server created for this purpose.

The DNS resolver maps the real IP address of a domain to a free IP address within a large internal subnet
and returns the internal subnet address to the requesting client.

This approach has several advantages:

* The client only needs one or a few routes instead of tens of thousands;
* Only domains from the list are routed, not all domains sharing the same IP address;
* The domain list can be updated without requiring the client to reconnect;
* Works correctly with domains that constantly change their IP addresses, as well as with CDN services.

But there are also downsides:

* Only the container’s DNS server can be used. Other DNS servers will not work;
* Works only for domains from the list and for programs that use these domain names.
  For IP addresses, standard routing must be used.

Schematic representation:

```
📱 — Client
🖥 — A container with a running DNS server
🖧 — Internet

📱 → chatgpt.com? → 🖥
  🖥 → chatgpt.com? → 🖧
  🖥 ← 172.64.155.209 ← 🖧
  10.224.0.1 → 172.64.155.209
📱 ← 10.224.0.1 ← 🖥
```

### Intentional Removal of IPv6 Addresses

The current version of the special DNS server does not support IPv6
and deliberately removes IPv6 addresses (AAAA records) from DNS responses.

This is not a significant drawback, as websites accessible only via IPv6 and not IPv4 are practically nonexistent.

## How to install a container?

**Log in to the system using SSH**:
the hosting provider usually provides the server’s IP address, login, and password.
All commands should be executed as the `root` user or with `sudo`.

### Automatic installation
### Manual installation

## How to uninstall a container?

## How to Choose the Right VPS?

Selecting the right VPS starts with two key factors:
the server’s physical location and its latency (ping).
These have the biggest impact on performance and user experience.

As for system requirements, only a few basics really matter.
Below you’ll find the minimum specs you should pay attention to -
everything else plays only a minor role and won’t significantly affect your setup.

### Minimum System Requirements for Choosing a VPS

* A dedicated server or VPS with XEN or KVM virtualization (OpenVZ is not suitable)
* A dedicated IPv4 address
* At least 1 GB of RAM
* At least 5 GB of disk space
* A Linux distribution with `systemd-machined` available (Debian 12/13 recommended)
* Unlimited traffic, or as much as possible =)

### What I Used and Can Recommend

> All links are referral links!!!

* [RoboVPS](https://www.robovps.biz/?ref=39155)
  * Usage period: 17.04.2022 - 17.10.2023
  * Very good and stable hosting, support responds quickly
    It was the optimal option in terms of price/quality until the prices increased
  * Available locations: Russia, USA, Germany, Netherlands and Finland

* [WebHOST1](https://webhost1.ru/?r=139105)
  * Usage period: 17.03.2022 - 17.04.2022
  * Tested the location in Chisinau, ping was good, but there were some freezes
    Previously, I had rented locations in Moldova from other hosting providers,
    and this is a common occurrence, so I don’t consider it a drawback
  * There is a trial period during which you can request a refund - I got my money back without any issues
  * A large number of locations at a good price, but servers are often unavailable.
    They do appear from time to time, so you need to keep monitoring =)
  * Available locations: Russia, Moldova, Israel, USA, Netherlands, Hong Kong, France, Armenia, Türkiye and Germany
  * You can pay with a 3-, 6- or 12-month discount

* [HOSTING RUSSIA](https://hosting-russia.ru/?p=37512)
  * Usage period: 17.10.2023 - present
  * Very good and stable hosting, support responds relatively quickly,
    but there was a case when it was simply unavailable during a DDoS attack
  * Available locations: Russia, Germany and Netherlands
  * You can pay with a 6- or 12-month discount

* [TimeWeb](https://timeweb.cloud/?i=127787)
  * Usage period: 20.06.2025 - present
  * Very good and stable hosting, support responds quickly
  * You can pay with a 3-, 6- or 12-month discount
  * Available locations: Russia, Germany, Netherlands and Kazakhstan

* [аéза]
  * **Account with a small balance was deleted without warning**
  * Tested on 21.02.2024 in USA, London, and Netherlands locations
  * Hourly billing

## About VPN Technology

Since March 2022, `%username%` learned a new word and, as is typical, gave it a new meaning -
access to all the benefits of humanity. But that’s not what it actually means!

**VPN (Virtual Private Network)** is a technology that provides a secure connection over the Internet
between different networks or devices, creating a single virtual network on top of the public one.

For example, the headquarters has its own local subnet.
Branches also have their own local subnets,
which may be located in the same city as the headquarters or in completely different cities.
The headquarters has no access to the branch subnets, and the branches have no access to each other’s subnets.

To establish such access, you need a machine that is "visible" to every subnet.
A VPN server is configured on this machine, and all subnets connect to it.
Now each subnet becomes part of a virtual network,
allowing devices to interact directly with each other as if they were on the same local network.

Thus, a **VPN solves** the key tasks:
**subnet unification**, **data encryption**, **tunneling**, and **authentication**.
All other benefits are merely side effects of this technology.
