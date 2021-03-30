#!/bin/sh

. ./config.env

if [ -z "$BUILDTIME_CMD" ]; then
  BUILDTIME_CMD=docker
fi

$BUILDTIME_CMD pull debian:bullseye
