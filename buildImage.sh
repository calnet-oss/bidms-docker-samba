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

if [ -f config.env ]; then
  . ./config.env || check_exit
else
  cat << EOF
Warning: There is no config.env file.  It is recommended you copy
config.env.template to config.env and edit it before running this, otherwise
the argument defaults in the Dockerfile will be used.
EOF
fi

if [ ! -z "$AD_DOMAIN" ]; then
  ARGS+="--build-arg AD_DOMAIN=$AD_DOMAIN "
fi
if [ ! -z "$AD_REALM" ]; then
  ARGS+="--build-arg AD_REALM=$AD_REALM "
fi
if [ ! -z "$AD_DC_HOSTNAME" ]; then
  ARGS+="--build-arg AD_DC_HOSTNAME=$AD_DC_HOSTNAME "
fi
if [ ! -z "$AD_BASE" ]; then
  ARGS+="--build-arg AD_BASE=$AD_BASE "
fi
if [ ! -z "$APT_PROXY_URL" ]; then
  ARGS+="--build-arg APT_PROXY_URL=$APT_PROXY_URL "
elif [ -e $HOME/.aptproxy ]; then
  apt_proxy_url=$(cat $HOME/.aptproxy)
  ARGS+="--build-arg APT_PROXY_URL=$apt_proxy_url "
fi

echo "Using ARGS: $ARGS"
docker build $ARGS -t bidms/samba:latest imageFiles || check_exit

#
# We want to temporarily start up the image so we can copy the contents of
# /var/lib/samba to the host.  On subsequent container runs, we will mount
# this host directory into the container.  i.e., we want to persist Samba
# directory data across container runs.
#
if [ ! -z "$HOST_SAMBA_DIRECTORY" ]; then
  if [ -e $HOST_SAMBA_DIRECTORY ]; then
    echo "$HOST_SAMBA_DIRECTORY on the host already exists.  Not copying anything."
    echo "If you want a clean install, delete $HOST_SAMBA_DIRECTORY and re-run this script."
    exit
  fi
  echo "Temporarily starting the container to copy /var/lib/samba to host"
  NO_INTERACTIVE="true" NO_HOST_SAMBA_DIRECTORY="true" ./runContainer.sh || check_exit
  TMP_SAMBA_HOST_DIR=$(./getSambaHostDir.sh)
  if [ $? != 0 ]; then
    echo "./getSambaHostDir.sh failed"
    docker stop bidms-samba
    exit 1
  fi

  echo "Temporary host samba directory: $TMP_SAMBA_HOST_DIR"
  echo "$HOST_SAMBA_DIRECTORY does not yet exist.  Copying from temporary location."
  echo "You must have sudo access for this to work and you may be prompted for a sudo password."
  sudo cp -pr $TMP_SAMBA_HOST_DIR $HOST_SAMBA_DIRECTORY || check_exit
  echo "Successfully copied to $HOST_SAMBA_DIRECTORY"
  
  echo "Stopping the container."
  docker stop bidms-samba || check_exit
fi
