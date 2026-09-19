#! /bin/bash

iptables -L

iptables -L > /tmp/firewall_$(date +%R)

read -rp "TCP Inbound Ports: " PORTS

IFS=','
for PORT in $PORTS;do
	iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT
done

read -rp "UDP Inbound Ports: " PORTS

IFS=','
for PORT in $PORTS;do
	iptables -A INPUT -p udp --dport "$PORT" -j ACCEPT
done

iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

iptables --policy INPUT DROP
iptables --policy OUTPUT DROP
iptables --policy FORWARD DROP

iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
