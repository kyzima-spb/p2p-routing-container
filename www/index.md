> **Не работает! Ведется работа по полному обновлению контейнера**

Router
======

- [Introduction](#introduction)
  - [Non-standard Routing Method](#non-standard-routing-method)
- [How to install a container?](#how-to-install-a-container)
  - [Automatic installation](#automatic-installation)
  - [Manual installation](#manual-installation)
- [How to uninstall a container?](#how-to-uninstall-a-container)
- [How to Choose the Right VPS?](#how-to-choose-the-right-vps)
  - [Minimum System Requirements for Choosing a VPS](#minimum-system-requirements-for-choosing-a-vps)
  - [What I Used and Can Recommend](#what-i-used-and-can-recommend)
- [Commands for Working with Clients](#commands-for-working-with-clients)
  - [How to create a client?](#how-to-create-a-client)

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

```shell
# Installing the container with default parameters
# The OpenVPN configuration file needs to be imported into the OpenVPN Connect application
wget -qO- https://kyzima-spb.github.io/router/installer.sh | \
  sudo bash -s -- --cn client > client.ovpn

# You can set a password, in which case the configuration will be saved in a ZIP archive
wget -qO- https://kyzima-spb.github.io/router/installer.sh | \
  sudo bash -s -- --cn client --password 'very secret' > client.zip

# You can specify your own name for the container
wget -qO- https://kyzima-spb.github.io/router/installer.sh | \
  sudo bash -s -- -n custom-router --cn client > client.ovpn

# You can specify a domain or a fixed port
wget -qO- https://kyzima-spb.github.io/router/installer.sh | \
  sudo bash -s -- --cn client --remote example.com -p 1194 > client.ovpn

# Or, if you need to use the TCP protocol
wget -qO- https://kyzima-spb.github.io/router/installer.sh | \
  sudo bash -s -- --cn client --proto tcp > client.ovpn

# For more details, see the help for the install command
wget -qO- https://kyzima-spb.github.io/router/installer.sh | \
  sudo bash -s -- install -h
```

All configuration files, certificates, and keys can be copied from the server to your computer
using FileZilla (Windows, macOS, Linux) or WinSCP (Windows only) over the **SFTP** protocol.

If you haven’t changed the directory after logging in, by default it is the user’s home directory.
For the root user, this is `/root`; for other users, it is `/home/<USERNAME>`.

On Linux, you can archive all the files and download them from the server with the command:

```shell
whoami  # root
pwd     # /root
tar -czf /root/credentials.tar.gz <PATH_1> <PATH_2> <PATH_N>
scp <USER>@<PUBLIC_IP>:/root/credentials.tar.gz <DEST_PATH>
```

### Manual installation

```shell
apt update && apt install -y gnupg systemd-container

gpg -k > /dev/null
gpg \
  --no-default-keyring \
  --keyring /etc/systemd/import-pubring.gpg \
  --keyserver hkps://keyserver.ubuntu.com \
  --receive-keys 0xA2AFF7EB363E6C8DD27655AD62CD962F89DDC0CD

machinectl pull-tar https://github.com/kyzima-spb/router/releases/download/v1.0/router.tar.xz
mkdir -p /etc/systemd/nspawn
tee /etc/systemd/nspawn/router.nspawn <<- EOF
[Exec]
NotifyReady=yes
PrivateUsers=yes

[Network]
VirtualEthernet=yes
Port=tcp:1194:1194
Port=udp:1194:1194
EOF

systemctl enable --now systemd-networkd.service
machinectl enable router
machinectl start router

# Wait for the VPN server configuration to be created
systemd-run -q -M router --wait --pipe journalctl -u openvpn-generate-keys -f | \
  grep -q 'Deactivated successfully.'
```

## How to uninstall a container?

To remove the container, the image, and all related files, run:

```shell
wget -qO- https://kyzima-spb.github.io/router/installer.sh | \
  sudo bash -s -- uninstall
```

If a different name was specified during installation, run:

```shell
wget -qO- https://kyzima-spb.github.io/router/installer.sh | \
  sudo bash -s -- uninstall -n custom-router
```

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

## Commands for Working with Clients

Client management for OpenVPN inside the container is handled by the `client-util` script.
For more details, see the help documentation. Here are a few examples for common use cases.

Commands can be executed inside the container:

```shell
# To login the container, use the command:
machinectl shell <CONTAINER_NAME>
# Inside the container, view the help for the command:
client-util -h
```

Or from the host:

```shell
systemd-run -q --wait --pipe -M <CONTAINER_NAME> client-util -h
```

### How to create a client?

To add a new client named `phone`, run the command:

```shell
systemd-run -q --wait --pipe -M <CONTAINER_NAME> client-util generate phone
```

To recreate the certificate and key for an existing client, use the `--revoke` argument.
This will revoke the previously issued certificate and key:

```shell
systemd-run -q --wait --pipe -M <CONTAINER_NAME> client-util generate phone --revoke
```

Deleting a client is not supported, but you can revoke the certificate and key issued to them.
To do this, run the command:

```shell
systemd-run -q --wait --pipe -M <CONTAINER_NAME> client-util revoke phone
```

To generate a configuration file for the OpenVPN Connect application, run the command:

```shell
systemd-run -q --wait --pipe -M <CONTAINER_NAME> client-util show phone > phone.ovpn
```

If the port was not explicitly specified during installation, a random available port will be used.
Inside the container, this port is unknown, so when generating OVPN files,
you need to explicitly specify the port:

```shell
VPN_PORT="$(grep '^Port=' /etc/systemd/nspawn/<CONTAINER_NAME>.nspawn | awk -F: '{print $2}' | head -1)"
systemd-run -q --wait --pipe -M <CONTAINER_NAME> client-util show phone -p "$VPN_PORT" > phone.ovpn
```


For more details, see the help for the client-util:

```shell
systemd-run -q --wait --pipe -M <CONTAINER_NAME> client-util -h
```

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
