#!/bin/bash

# this uses the OpenLDAP ldapsearch client to query AD

. ./config.env

LDAPTLS_REQCERT=allow
export LDAPTLS_REQCERT

ldapsearch -x -W \
  -D "cn=Administrator,cn=Users,$AD_BASE" \
  -b "$AD_BASE" -LLL \
  -s sub \
  -H ldaps://localhost:636/ "(objectClass=top)" dn
