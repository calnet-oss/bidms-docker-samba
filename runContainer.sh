#!/bin/bash

#
# Copyright (c) 2017, Regents of the University of California and
# contributors.
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
# IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 

function check_exit {
  error_code=$?
  if [ $error_code != 0 ]; then
    echo "ERROR: last command exited with an error code of $error_code"
    exit $error_code
  fi
}

if [ ! -z "$CONFIG_FILE" ]; then
  if [ ! -f $CONFIG_FILE ]; then
    echo "$CONFIG_FILE does not exist as a file"
    exit 1
  fi
elif [ -f ./config.env ]; then
  CONFIG_FILE=./config.env
elif [ -f ./config.env.template ]; then
  cat << EOF
Warning: There is no config.env file.  It is recommended you copy
config.env.template to config.env and edit it before running this, otherwise
I'm assuming you want the defaults from config.env.template.
EOF
  CONFIG_FILE=./config.env.template
else
  echo "There is no config.env file nor a config.env.template fallback.  Can't continue."
  exit 1
fi

echo "Using config values from $CONFIG_FILE"
. $CONFIG_FILE && check_exit

EXISTINGNAMESERVERS=$(grep nameserver /etc/resolv.conf|awk '{print $2}')
check_exit
DNSPARAMS="--dns 127.0.0.1 "
while read -r line; do
    DNSPARAMS+="--dns $line "
done <<< "$EXISTINGNAMESERVERS"
echo "DNSPARAMS=$DNSPARAMS"

if [ ! -z "$AD_REALM" ]; then
  echo "AD_REALM=$AD_REALM"
  DNSSEARCHPARAMS="--dns-search $AD_REALM "
else
  echo "ERROR: Required AD_REALM value missing from $CONFIG_FILE"
  exit 1
fi

if [ ! -z "$AD_DC_HOSTNAME" ]; then
  echo "AD_DC_HOSTNAME=$AD_DC_HOSTNAME"
else
  echo "ERROR: Required AD_DC_HOSTNAME value missing from $CONFIG_FILE"
  exit 1
fi

if [ ! -z "$CONTAINER_IP4_ADDR" ]; then
  echo "CONTAINER_IP4_ADDR=$CONTAINER_IP4_ADDR"
else
  echo "ERROR: Required CONTAINER_IP4_ADDR value missing from $CONFIG_FILE"
  exit 1
fi

if [ ! -z "$LOCAL_DIR_SSL_PORT" ]; then
  echo "LOCAL_DIR_SSL_PORT=$LOCAL_DIR_SSL_PORT"
else
  echo "ERROR: Required LOCAL_DIR_SSL_PORT value missing from $CONFIG_FILE"
  exit 1
fi

if [[ -z "$NO_HOST_SAMBA_DIRECTORY" && ! -z "$HOST_SAMBA_DIRECTORY" ]]; then
  echo "HOST_SAMBA_DIRECTORY=$HOST_SAMBA_DIRECTORY"
  MOUNTPARAMS="-v $HOST_SAMBA_DIRECTORY:/var/lib/samba"
else
  # Docker will choose where it wants to put it on the host.
  # Use docker inspect bidms-samba to find out where.
  echo "HOST_SAMBA_DIRECTORY not set.  Using docker default."
fi

if [[ -z "$NO_INTERACTIVE" && -z "$INTERACTIVE_PARAMS" ]]; then
  INTERACTIVE_PARAMS="-ti"
elif [ ! -z "$NO_INTERACTIVE" ]; then
  INTERACTIVE_PARAMS="-d --entrypoint /etc/container/samba-entrypoint.sh"
  ENTRYPOINT_ARGS="detached"
fi

docker run $INTERACTIVE_PARAMS --rm --name "bidms-samba" \
  -h $AD_DC_HOSTNAME \
  --add-host "${AD_DC_HOSTNAME}.${AD_REALM} ${AD_DC_HOSTNAME}:${CONTAINER_IP4_ADDR}" \
  $DNSPARAMS \
  $DNSSEARCHPARAMS \
  $MOUNTPARAMS \
  -p $LOCAL_DIR_SSL_PORT:636 \
  $* \
  bidms/samba:latest \
  $ENTRYPOINT_ARGS && check_exit

if [ ! -z "$NO_INTERACTIVE" ]; then
  echo "Running in detached mode.  Stop the container with 'docker stop bidms-samba'."
fi
