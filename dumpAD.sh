#!/bin/bash

# this uses the OpenLDAP ldapsearch client to query AD

. ./config.env

LDAPTLS_REQCERT=allow
export LDAPTLS_REQCERT

ldapsearch -x -y imageFiles/tmp_ad_passwords/ad_admin_pw \
  -D "cn=Administrator,cn=Users,$AD_BASE" \
  -b "$AD_BASE" -LLL \
  -s sub \
  -H ldaps://$CONTAINER_IP4_ADDR:636/ "(objectClass=top)" dn
