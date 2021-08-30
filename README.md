# nftables / iptables firewall including multi routing

Hi, this is the Iptables firewall script I've been using for years.
I recently switched to nftables but feel like this content still can
be relevant for some of you.

It includes the classical protections on input / forward and output
chains but also has some "multiroute" system included. The basic 
principle is to have several connexion, say a FDDI, a 4G and a VPN
for exemple and Mangle (modify) the packets to force them to flow
through the proper connexion.

If you want your work computers to use FDDI connexion, your other
devices 4G and leverage VPN only for your TV when using Netflix or 
downloading, this script is made for you.

It levrerages ip route, ip rules and iptables mangles.

Some few exemples are included, don't hesitate to adapt.
Also, I'm joining the nftables translation of thoses iptables.

Finally, you'll also find some port knocking rules in the nftables
script, you can also see similar knockd rules in the iptables ruleset
but this one relies on ipsets, joining an exemple as well.

PS:   No worries, no IPs / port inside this script are real.
PPS:  The iptables script and the nftables.conf are made to reflect
      the same ruleset, to help you convert your own rules if need be.
PPPS: For nftables, you'll need to kick multiroute.sh apart since the
      nftables.conf is loaded by the system at boot time, but cannot
      contain bash command. The knockd config is also different.

Philippe.
