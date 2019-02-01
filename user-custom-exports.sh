#!/bin/bash

export USERNAME="admin"
export PASSWORD="admin"
export IP=${IP:="$(ip route get 114.114.114.114 | awk '{print $NF; exit}')"}
export DOMAIN="${IP}.nip.io" 
export DISK="" 
