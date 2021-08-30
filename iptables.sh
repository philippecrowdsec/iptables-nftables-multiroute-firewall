#!/bin/bash

### BEGIN INIT INFO
# Provides:             firewall
# Required-Start:       $network
# Required-Stop:        $network
# Should-Start:         
# Should-Stop:
# Default-Start:        2 3 4 5
# Default-Stop:         0 1 6
# Short-Description:    Firewalling script and multiroute manager
# Description:          Manage the input/forward/output/prerouting/postrouting and multi routing, by Philippe @ CrowdSec
### END INIT INFO

Set_variables()
{
  BLUE="\e[1;36m"
  YELLOW="\e[1;33m"
  ORANGE="\e[38;5;208m"
  PURPLE="\e[1;35m"
  GREEN="\e[1;32m"
  RED="\e[1;31m"
  END="\e[0m"
  OLDIFS="$IFS"
  IPTABLES="/sbin/iptables"
  DATE=`date +'%b %d %k:%M:%S'`
  WAN="eth0"
  LAN="eth1"
  WAN2="eth2"
  VPN=`ifconfig|grep tun0`
  VPNSERVER=`ifconfig|grep tun1`
  [[ ! -z "$VPN" ]] && VPNIF="tun0" && VPN=1 && VPNCLIENTIP=`ip -o addr | grep -v inet6 | grep tun0 | awk '{split($4, a, "/"); print a[1]}'` && VPNCLIENTROUTE=`ip route show|grep -v inet6 | grep "tun0 proto" | cut -f 1 -d " "`
  [[ ! -z "$VPNSERVER" ]] && VPNSERVERIF="tun1" && VPNSERVER=1 && VPNSERVERIP=`ip -o addr |grep -v inet6 | grep $VPNSERVERIF |awk '{split($4, a, "/"); print a[1]}'` && VPNSERVERROUTE=`ip route show |grep -v inet6 | grep $VPNSERVERIF | cut -f 1 -d " " | head -1`
  PUBLIC_IP="43.43.43.43" # your public IP
}

Routing_Init()
{ 
  echo -e "$ORANGE -> CREATING MULTI-ROUTING TABLE $END"
  [[ $VPN ]] && echo -e "$ORANGE -> VPN IS UP (route: $VPNCLIENTROUTE, on dev: $VPNIF, ip: $VPNCLIENTIP) $END"

  ip route add table maincnx default dev $WAN via 192.168.1.2
  ip route add table maincnx 192.168.0.0/24 dev $LAN src 192.168.0.1
  ip route add table maincnx 192.168.1.0/24 dev $WAN src 192.168.1.1
  ip route add table maincnx 192.168.2.0/24 dev $WAN2 src 192.168.2.1
  [[ $VPN ]] && ip route add table maincnx $VPNCLIENTROUTE dev $VPNIF src $VPNCLIENTIP
  [[ $VPNSERVER ]] && ip route add table maincnx 10.0.0.0/24 dev $VPNSERVERIF src 10.0.0.1
  ip rule add from 192.168.1.2 table maincnx

  [[ $VPN ]] && ip route add table vpnclient default dev $VPNIF via $VPNCLIENTIP
  [[ $VPN ]] && ip route add table vpnclient $VPNCLIENTROUTE dev $VPNIF src $VPNCLIENTIP
  [[ $VPN ]] && ip route add table vpnclient 192.168.0.0/24 dev $LAN src 192.168.0.1
  [[ $VPN ]] && ip route add table vpnclient 192.168.1.0/24 dev $WAN src 192.168.1.1
  [[ $VPN ]] && ip route add table vpnclient 192.168.2.0/24 dev $WAN2 src 192.168.2.1
  ip rule add from $VPNCLIENTIP table vpnclient 

  [[ $VPNSERVER ]] && ip route add table vpnserver default dev $VPNSERVERIF via $VPNSERVERIP
  [[ $VPNSERVER ]] && ip route add table vpnserver 192.168.0.0/24 dev $LAN src 192.168.0.1
  [[ $VPNSERVER ]] && ip route add table vpnserver 192.168.1.0/24 dev $WAN src 192.168.1.1
  [[ $VPNSERVER ]] && ip route add table vpnserver 192.168.2.0/24 dev $WAN2 src 192.168.2.1
  [[ $VPNSERVER ]] && ip route add table vpnserver 10.0.0.0/24 dev $VPNSERVERIF src 10.0.0.1
  [[ $VPNSERVER ]] && ip rule add from $VPNSERVERIP table vpnserver 

  ip route add table altcnx default dev $WAN2 via 192.168.2.2
  ip route add table altcnx 192.168.0.0/24 dev $LAN src 192.168.0.1
  ip route add table altcnx 192.168.1.0/24 dev $WAN src 192.168.1.1
  ip route add table altcnx 192.168.2.0/24 dev $WAN2 src 192.168.2.1
  ip rule add from 192.168.2.2 table altcnx

  ip rule add from all fwmark 1 table maincnx
  [[ $VPN ]] && ip rule add from all fwmark 2 table vpnclient
  [[ $VPNSERVER ]] && ip rule add from all fwmark 3 table vpnserver
  ip rule add from all fwmark 4 table altcnx
  ip route flush cache
}

Env_Cleanup()
{
  echo -e "$RED -> CLEANING UP$END"
  $IPTABLES -F
  $IPTABLES -Z
  $IPTABLES -X
  $IPTABLES -t nat -F
  $IPTABLES -t nat -Z
  $IPTABLES -t nat -X
  $IPTABLES -t mangle -F
  $IPTABLES -t mangle -Z
  $IPTABLES -t mangle -X
  $IPTABLES -F INPUT
  $IPTABLES -F OUTPUT
  $IPTABLES -F FORWARD
  $IPTABLES -F LOGDROP_NWL
  $IPTABLES -F LOGDROP_PKT

  ip rule del from all fwmark 1 2>/dev/null
  ip rule del from all fwmark 2 2>/dev/null 
  ip rule del from all fwmark 3 2>/dev/null
  ip rule del from all fwmark 4 2>/dev/null
  ip rule del lookup maincnx    2>/dev/null
  ip rule del lookup vpnclient  2>/dev/null 
  ip rule del lookup vpnserver  2>/dev/null
  ip rule del lookup altcnx     2>/dev/null
  ip route flush table maincnx
  ip route flush table vpnclient
  ip route flush table vpnserver
  ip route flush table altcnx
  
  for i in /proc/sys/net/ipv4/conf/*/rp_filter; do echo 0 > "$i"; done # To avoid packet drop

  echo -e "$GREEN -> CREATING IPSETS AND CUSTOM IPTABLES TARGETS$END"
  ipset -q create whitelist hash:ip timeout 3600
  ipset -q add whitelist $PUBLIC_IP timeout 0
  ipset -q create blacklist hash:ip timeout 0
  ipset -q add blacklist 42.42.42.42/20 timeout 0 # exemple
 
  $IPTABLES -N LOGDROP_NWL
  $IPTABLES -A LOGDROP_NWL -j LOG --log-prefix "Not_in_whitelist "
  $IPTABLES -A LOGDROP_NWL -j DROP
  $IPTABLES -N LOGDROP_PKT
  $IPTABLES -A LOGDROP_PKT -j LOG --log-prefix "Packets_trick "
  $IPTABLES -A LOGDROP_PKT -j DROP
}

Settingup_Prerouting()
{
  echo -e "$BLUE -> PREROUTING$END"
  $IPTABLES -t nat -A PREROUTING -m set --match-set whitelist src -p tcp --dport 81   -j DNAT --to 192.168.0.100     
  $IPTABLES -t nat -A PREROUTING -m set --match-set whitelist src -p tcp --dport 80   -j DNAT --to 192.168.0.50:8080
  $IPTABLES -t nat -A PREROUTING -m set --match-set whitelist src -p tcp --dport 2222 -j DNAT --to 192.168.0.33:22        
  $IPTABLES -t nat -A PREROUTING -m set --match-set whitelist src -p tcp --dport 3389 -j DNAT --to 192.168.0.45        
  $IPTABLES -t nat -A PREROUTING -m set --match-set whitelist src -p tcp --dport 8890 -j DNAT --to 192.168.1.2:443 # ISP Box
}

Settingup_VPN_rules()
{ 
  echo -e "$ORANGE -> ADDING SPECIFIC VPN RULES TO SPLIT TRAFFIC$END"
  $IPTABLES -t mangle -A PREROUTING                                     -j CONNMARK --restore-mark # Restore prev set marks
  $IPTABLES -t mangle -A PREROUTING -m mark ! --mark 0                  -j ACCEPT            # If a mark exist, skip
  $IPTABLES -t mangle -A PREROUTING -s 192.168.0.2 -p tcp --sport 50001 -j MARK --set-mark 2 # route through connexion 2
  $IPTABLES -t mangle -A PREROUTING -s 192.168.0.2 -p udp --sport 50001 -j MARK --set-mark 2 # route through connexion 2
  $IPTABLES -t mangle -A PREROUTING -s 192.168.0.3 -p tcp --dport 1000  -j MARK --set-mark 2 # route through connexion 2
  $IPTABLES -t mangle -A PREROUTING -s 192.168.0.4                      -j MARK --set-mark 4 # route through connexion 4
  $IPTABLES -t mangle -A PREROUTING -s 192.168.0.6                      -j MARK --set-mark 1 # by default, everyting is mark 1 anyway :)
  $IPTABLES -t mangle -A POSTROUTING                                    -j CONNMARK --save-mark # save the marks we've set
}

Settingup_Input()
{
  echo -e "$BLUE -> INPUT$END"
  $IPTABLES -A INPUT -i $LAN                                            -j ACCEPT
  $IPTABLES -A INPUT -i lo                                              -j ACCEPT
  $IPTABLES -A INPUT -m state --state RELATED,ESTABLISHED               -j ACCEPT
  $IPTABLES -A INPUT -m set --match-set whitelist src                   -j ACCEPT
  [[ $VPNSERVER ]] && $IPTABLES -A INPUT -i $VPNSERVERIF                -j ACCEPT
  $IPTABLES -A INPUT -i $WAN -m set ! --match-set whitelist src         -j LOGDROP_NWL
  $IPTABLES -A INPUT -i $WAN -m state --state INVALID                   -j LOGDROP_PKT
  $IPTABLES -A INPUT -p tcp --tcp-flags ALL FIN,URG,PSH                 -j LOGDROP_PKT
  $IPTABLES -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG         -j LOGDROP_PKT
  $IPTABLES -A INPUT -p tcp --tcp-flags ALL ALL                         -j LOGDROP_PKT
  $IPTABLES -A INPUT -p tcp --tcp-flags ALL FIN                         -j LOGDROP_PKT
  $IPTABLES -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST                 -j LOGDROP_PKT
  $IPTABLES -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN                 -j LOGDROP_PKT
  $IPTABLES -A INPUT -p tcp --tcp-flags ALL NONE                        -j LOGDROP_PKT
  $IPTABLES -A INPUT -p tcp --dport 0                                   -j LOGDROP_PKT
  $IPTABLES -A INPUT -p udp --dport 0                                   -j LOGDROP_PKT
  $IPTABLES -A INPUT -p tcp --sport 0                                   -j LOGDROP_PKT
  $IPTABLES -A INPUT -p udp --sport 0                                   -j LOGDROP_PKT
}

Settingup_Forward()
{
  echo -e "$BLUE -> FORWARD$END"
  $IPTABLES -A FORWARD -i $LAN                                           -j ACCEPT
  $IPTABLES -A FORWARD -m set --match-set whitelist src                  -j ACCEPT
  $IPTABLES -A FORWARD -m state --state RELATED,ESTABLISHED              -j ACCEPT
  [[ $VPNSERVER ]] && $IPTABLES -A FORWARD -i $VPNSERVERIF               -j ACCEPT
  [[ $VPN ]] && $IPTABLES -A FORWARD -d 192.168.0.2 -p udp --dport 50001 -j ACCEPT
  [[ $VPN ]] && $IPTABLES -A FORWARD -d 192.168.0.2 -p tcp --dport 50001 -j ACCEPT
  [[ $VPN ]] && $IPTABLES -A FORWARD -d 192.168.0.3 -p tcp --dport 1000  -j ACCEPT
}

Settingup_Postrouting()
{
  echo -e "$BLUE -> POSTROUTING$END"
  $IPTABLES                     -t nat -A POSTROUTING -o $WAN         -j SNAT --to-source 192.168.1.1
  $IPTABLES                     -t nat -A POSTROUTING -o $WAN2        -j SNAT --to-source 192.168.2.1
  [[ $VPN ]] && $IPTABLES       -t nat -A POSTROUTING -o $VPNIF       -j SNAT --to-source $VPNCLIENTIP
  [[ $VPNSERVER ]] && $IPTABLES -t nat -A POSTROUTING -o $VPNSERVERIF -j SNAT --to-source $VPNSERVERIP
}

Settingup_Defaultpolicies()
{
  echo -e "$RED -> DEFAULT POLICIES$END"
  $IPTABLES -P INPUT   DROP
  $IPTABLES -P FORWARD DROP
  $IPTABLES -P OUTPUT  ACCEPT
}

case "$1" in 

start)
  Set_variables
  [[ $VPN ]] && sleep 5 # Wait for VPN to be up if not yet started when the firewall script kicks in at boot time
  /usr/bin/logger -t "Firewall" "Starting" -p4
  /usr/bin/logger -t "Firewall" "VPN CLIENT DETECTED, ADDING RULES" -p4
  /usr/bin/logger -t "Firewall" "VPN SERVER DETECTED, ADDING RULES" -p4
  echo -e "$PURPLE -----------------> $DATE: FW Starting <------------------$END"
  Env_Cleanup
  Routing_Init
  Settingup_Prerouting
  [[ $VPN ]] && Settingup_VPN_rules
  Settingup_Input
  Settingup_Forward
  Settingup_Postrouting
  Settingup_Defaultpolicies
  echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward > /dev/null
  echo -e "$PURPLE --------------------------> FW active <----------------------------$END"
  exit 0
;;

stop)
  Set_variables
  echo -e "$RED -------------------> Shutting down Firewall ! <--------------------$END"
  /usr/bin/logger -t "Firewall" "Stopped" -p4
  echo 0 | sudo tee /proc/sys/net/ipv4/ip_forward > /dev/null
  $IPTABLES -F
  $IPTABLES -t nat -F
  $IPTABLES -t mangle -F
  $IPTABLES -F INPUT
  $IPTABLES -F OUTPUT
  $IPTABLES -F FORWARD
  ip rule del from all fwmark 1 2>/dev/null
  ip rule del from all fwmark 2 2>/dev/null
  ip rule del from all fwmark 3 2>/dev/null
  ip rule del from all fwmark 4 2>/dev/null
  ip route flush cache
  $IPTABLES -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
  $IPTABLES -A INPUT -i $LAN -j ACCEPT
  echo -e "$RED ----------------------> Firewall disabled <------------------------$END"
  exit 0
;;

status)
  Set_variables
  echo -e "$GREEN --------------------> Firewall status end <---------------------$END"
  echo -e "$GREEN ----------------------> NAT rules       <----------------------$END"
  $IPTABLES -t nat -L -n
  echo -e "$GREEN ----------------------> Other rules     <----------------------$END"
  $IPTABLES -L -n
  echo -e "$YELLOW ---------------------> Routing tables <-----------------------$END" 
  ip route show table maincnx
  ip route show table alt
  [[ $VPN ]] && ip route show table vpnsrv
  [[ $VPN ]] && ip route show table vpn
  [[ $VPN ]] && echo -e "$YELLOW --------------------> VPN related rules <---------------------$END" 
  [[ $VPN ]] && ip rule show
  [[ $VPN ]] && echo -e "$YELLOW -------------------> VPN related mangles <--------------------$END" 
  [[ $VPN ]] && iptables -t mangle -nvL
  echo -e "$PURPLE --------------------> Ip fwd and sysctl <---------------------$END"
  cat /proc/sys/net/ipv4/ip_forward
  cat /etc/sysctl.conf | grep -v "\#"
  echo -e "$PURPLE --------------------> Firewall status end <---------------------$END"
  exit 0
;;			  

vpnstart)
  Set_variables
  echo -e "$PURPLE --------------------> VPN RULES ACTIVATED <--------------------$END"
  /usr/bin/logger -t "Firewall" "(only) VPN rules added" -p4
  [[ $VPN ]] && sleep 5
  [[ $VPN ]] && Routing_Init
  [[ $VPN ]] && Settingup_VPN_rules
  echo -e "$PURPLE --------------------> END OF VPN KICK-OFF <---------------------$END"
;;

vpnstop)
  Set_variables
  echo -e "$PURPLE -------------------> VPN RULES DEACTIVATED <--------------------$END"
  /usr/bin/logger -t "Firewall" "(only) VPN rules removed" -p4
  $IPTABLES -t mangle -F
  $IPTABLES -F FORWARD  
  ip rule del from all fwmark 2 2>/dev/null
  ip rule del from all fwmark 3 2>/dev/null
  ip route flush cache
  Settingup_Forward
  Settingup_Defaultpolicies
  echo -e "$PURPLE -------------------> END OF VPN STOP      <--------------------$END"
;;

restart)
  /usr/bin/logger -t "Firewall" "restart initiated" -p4
  $0 stop
  sleep 1
  echo -e '\n'
  $0 start
;;				  

*)
  echo -e "$YELLOW Usage: /etc/init.d/firewall {start|stop|status|restart|vpnstart|vpnstop}$END"
  exit 1
;;

esac
exit 0
