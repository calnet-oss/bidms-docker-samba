#!/bin/sh

. ./config.env

if [ -z "$RUNTIME_CMD" ]; then
  RUNTIME_CMD=docker
fi

if [ ! -z "$USE_SUDO" ]; then
  SUDO=sudo
fi

$SUDO $RUNTIME_CMD stop bidms-samba
