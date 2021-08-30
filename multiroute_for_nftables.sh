#!/bin/bash

### BEGIN INIT INFO
# Provides:             multiroute
# Required-Start:       $network
# Required-Stop:        $network
# Should-Start:         
# Should-Stop:
# Default-Start:        2 3 4 5
# Default-Stop:         0 1 6
# Short-Description:    Multiroute manager
# Description:          Manage multi-routing
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
  DATE=`date +'%b %d %k:%M:%S'`
  WAN="eth0"
  LAN="eth1"
  WAN2="eth2"
  VPN=`ifconfig|grep tun0`
  VPNSERVER=`ifconfig|grep tun1`
  [[ ! -z "$VPN" ]] && VPNIF="tun0" && VPN=1 && VPNCLIENTIP=`ip -o addr | grep -v inet6 | grep tun0 | awk '{split($4, a, "/"); print a[1]}'` && VPNCLIENTROUTE=`ip route show|grep -v inet6 | grep "tun0 proto" | cut -f 1 -d " "`
  [[ ! -z "$VPNSERVER" ]] && VPNSERVERIF="tun1" && VPNSERVER=1 && VPNSERVERIP=`ip -o addr |grep -v inet6 | grep $VPNSERVERIF |awk '{split($4, a, "/"); print a[1]}'` && VPNSERVERROUTE=`ip route show |grep -v inet6 | grep $VPNSERVERIF | cut -f 1 -d " " | head -1`
}

Env_Cleanup()
{
  echo -e "$RED -> CLEANING UP$END"  
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
  
  for i in /proc/sys/net/ipv4/conf/*/rp_filter; do echo 0 > "$i"; done # To avoid packet drop
  echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward > /dev/null
}

case "$1" in 

start)
  Set_variables
  [[ $VPN ]] && sleep 5 # Wait for VPN to be up if not yet started when the firewall script kicks in
  /usr/bin/logger -t "Multi route" "Starting" -p4
  /usr/bin/logger -t "Multi route" "VPN CLIENT DETECTED, ADDING RULES" -p4
  /usr/bin/logger -t "Multi route" "VPN SERVER DETECTED, ADDING RULES" -p4
  echo -e "$PURPLE --------------> $DATE: Multi routing Start <-------------$END"
  Env_Cleanup
  Routing_Init
  echo -e "$PURPLE -----------------> Multi routing active <----------------$END"
  exit 0
;;

stop)
  Set_variables
  echo -e "$RED ------------> Deactivating Multi Route ! <------------------$END"
  /usr/bin/logger -t "Multi route" "Stopped" -p4
  echo 0 | sudo tee /proc/sys/net/ipv4/ip_forward > /dev/null
  ip rule del from all fwmark 1 2>/dev/null
  ip rule del from all fwmark 2 2>/dev/null
  ip rule del from all fwmark 3 2>/dev/null
  ip rule del from all fwmark 4 2>/dev/null
  ip route flush cache
  echo -e "$RED ----------------------> Firewall disabled <------------------------$END"
  exit 0
;;

restart)
  /usr/bin/logger -t "Multiroute" "restart initiated" -p4
  $0 stop
  sleep 1
  echo -e '\n'
  $0 start
;;				  

*)
  echo -e "$YELLOW Usage: /etc/init.d/multiroute.sh {start|stop|restart}$END"
  exit 1
;;

esac
exit 0
