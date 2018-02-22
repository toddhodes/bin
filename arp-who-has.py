#!/usr/bin/python
# Send arp who-has remote_ip to broadcast MAC
from scapy.all import *
from scapy.layers.l2 import ARP, Ether
 
broadcast_mac="ff:ff:ff:ff:ff:ff"
remote_ip="10.38.8.103"
pkt = Ether(dst=broadcast_mac)/ARP(op=ARP.who_has, pdst=remote_ip)
sendp(pkt, verbose=0)
