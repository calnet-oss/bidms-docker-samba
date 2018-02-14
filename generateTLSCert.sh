#!/bin/sh

# Generates an unencrypted self signed key pair.

if [ -z "$KEYSIZE" ]; then
  KEYSIZE=4096
fi

if [ ! -e imageFiles/tls/key.pem ]; then
  echo "Generating key.  This can take a few seconds."
  openssl req \
    -newkey rsa:$KEYSIZE -sha256 -nodes \
    -subj "/CN=bidms-samba/OU=BIDMS Samba Docker Dev/" \
    -keyout imageFiles/tls/key.pem \
    -x509 \
    -days 10000 \
    -out imageFiles/tls/cert.pem \
  && chmod 600 imageFiles/tls/key.pem \
  && cp imageFiles/tls/cert.pem imageFiles/tls/ca.pem
else
  echo "imageFiles/tls/key.pem already exists"
  exit 1
fi
