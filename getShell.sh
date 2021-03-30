#!/bin/sh

. ./config.env

if [ -z "$RUNTIME_CMD" ]; then
  RUNTIME_CMD=docker
fi

$RUNTIME_CMD exec -i -t bidms-samba /bin/bash 
