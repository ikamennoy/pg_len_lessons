#!/bin/bash
yc compute instance delete va --async
yc compute instance delete vd --async
yc compute instance delete vb
yc vpc subnet list|grep central|cut -d "|" -f 2 |xargs -n 1 yc vpc subnet delete
yc vpc network delete testnet
yc compute instance list
yc vpc network list
yc vpc subnet list
