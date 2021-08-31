# Netfilter (nftables & iptables) firewall, including multi-routing system

Hi, this is the Iptables firewall script I've been using for years.
I recently switched to nftables but feel like this content still can
be relevant and mainly that it could help those also migrating from
iptables to nftables, looking for real world examples.

It includes the classical protections on input / forward and output
chains but also has some "multiroute" system included. The basic 
principle is to have several connexion, say a FDDI, a 4G and a VPN
for example and Mangle (modify) the packets to force them to flow
through the proper connexion depending on src/dst ip, src/dst port 
or whatever else you need.

IE: If you want your work computers to use FDDI connexion, your other
devices 4G and leverage VPN only for your TV when using Netflix or 
downloading, this script is made for you.

It leverages knocked, ip route, ip rules and nftables or iptables mangles.

Those are really just examples, don't hesitate to adapt.
The nftables script is almost 100% identical to the iptables one in 
terms of usage and goals, to make it easier to adapt your own rules.

You'll find some port knocking rules in the nftables script, you can 
also see similar knockd rules in the iptables ruleset but this one 
relies on ipsets, that is now merged with nftables.

PS:  No worries, no IPs / port inside this script are the real ones, 
     I'm not leaking my own network typology ;-)

PPS: For nftables, you'll need to kick multiroute.sh apart since the
     nftables.conf is loaded by the system at boot time, but cannot
     contain bash command. The knockd config is also different. Here 
     a SYSV init file is provided, but you can easily adapt a systemd
     service for it.

Philippe.
