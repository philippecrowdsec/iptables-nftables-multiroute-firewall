# Netfilter (nftables & iptables) firewall, with port knocking and multi-routing system

This repo has the Iptables firewall script I've been using for years,
converted in Nftables. Beyond the rulesets that makes it (hopefully)
a decent firewall, I kept both versions as close to one another as
possible, to give hints & tricks on how to migrate from Iptables to
Nftables.

It includes the classical protections on input / forward and output
chains but also has some "multiroute" system included. The basic 
principle is to have several connexion, say a FDDI, a 4G and a VPN
for example and Mangle (modify) the packets to force them to flow
through the proper connexion depending on src/dst ip, src/dst port 
or whatever else you need.

IE: If you want your work computers to use FDDI connexion, your other
devices 4G and leverage VPN only for your TV when using Netflix or 
downloading, this script is made for you.

It leverages knocked, ip route, ip rules and nftables or iptables 
mangles and also offers some extra protection against LAN scans for 
exemple, which can play nice with CrowdSec's firewall bouncer.

You'll find some port knocking rules in the nftables script, you can 
also see similar knockd rules in the iptables ruleset but this one 
relies on ipsets, that is now merged with nftables. Btw, I kept knockd
even with nftables since it allowd me to extend the range of the IP
knocking, to cover the CGNAT issue (your mobile 4G connexion using
different IPs, hopefully in the same range, when you port knock).

PS:  No worries, no IPs / port inside this script are the real ones, 
     I'm not leaking my own network typology ;-)

PPS: For nftables, you'll need to kick multiroute.sh apart since the
     nftables.conf is loaded by the system at boot time, but cannot
     contain bash command. The knockd config is also different. Here 
     a SYSV init file is provided for iptables, but you can easily 
     adapt a systemd service for it. There are vpnstart and vpnstop
     entries so you can put a /etc/init.d/firewall vpnstart or stop
     at the end of your openvpn config file.

Philippe.
