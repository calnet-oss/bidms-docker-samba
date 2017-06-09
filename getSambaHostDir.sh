#!/bin/bash

CONTAINER_DIR="/var/lib/samba"
INSPECT=$(docker inspect bidms-samba | sed -e '/Source/,/Destination/!d')

while read -ra arr; do
  if [ "${arr[0]}" == '"Source":' ]; then
    src=${arr[1]}
  elif [[ "${arr[0]}" == '"Destination":' && "${arr[1]}" == "\"$CONTAINER_DIR\"," ]]; then
    samba_src=$src
  fi
done  <<< "$INSPECT"
samba_src=$(echo $samba_src|cut -d'"' -f2)

echo $samba_src
