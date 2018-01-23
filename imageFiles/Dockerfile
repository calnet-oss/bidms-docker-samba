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
FROM bidms/debian_base

ARG APT_PROXY_URL=
RUN if [ ! -z "$APT_PROXY_URL" ]; then echo "Acquire::http::Proxy \"$APT_PROXY_URL\";" > /etc/apt/apt.conf.d/00aptproxy; else echo "not using apt proxy"; fi

RUN set -x \
  && export DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
  && apt-get dist-upgrade -y \
  && apt-get install -y bind9-host dnsutils telnet krb5-user \
       samba winbind ldb-tools tdb-tools expect \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/*

COPY root/ /root/

# Samba AD Domain Controller set up
ARG AD_REALM=example.com
ARG AD_DOMAIN=example
ARG AD_DC_HOSTNAME=dc1
ARG AD_BASE=dc=example,dc=com
COPY tmp_ad_passwords /tmp/tmp_ad_passwords/
RUN set -x \
  && mv /etc/samba/smb.conf /etc/samba/smb.conf.ORIG \
  && mv /etc/krb5.conf /etc/krb5.conf.ORIG \
  && samba-tool domain provision \
       --use-rfc2307 \
       --realm="$AD_REALM" \
       --domain="$AD_DOMAIN" \
       --server-role="dc" \
       --dns-backend="SAMBA_INTERNAL" \
       --adminpass=Passw0rd \
       --host-name="$AD_DC_HOSTNAME" \
       --option="log level=1" \
       --option="log file=/var/log/samba/samba.log" \
       --option="ldap ssl ads=yes" \
  && samba-tool domain passwordsettings set --max-pwd-age=0

# Add additional indexes
# searchFlags, the index indicator attribute, is documented:
# https://msdn.microsoft.com/en-us/library/ms679765(v=vs.85).aspx
RUN sed -i "s/AD_BASE/$AD_BASE/" /root/indexModifications.ldif \
  && ldbmodify -H /var/lib/samba/private/sam.ldb \
       /root/indexModifications.ldif \
       --option="dsdb:schema update allowed"=true

COPY etc/krb5.conf /etc

RUN set -x \
  && AD_REALM_UPPER=$(echo "$AD_REALM"|tr '[:lower:]' '[:upper:]') \
  && AD_REALM_LOWER=$(echo "$AD_REALM"|tr '[:upper:]' '[:lower:]') \
  && sed -i "s/EXAMPLE.COM/${AD_REALM_UPPER}/" /etc/krb5.conf \
  && sed -i "s/example.com/${AD_REALM_LOWER}/" /etc/krb5.conf \
  && sed -i "s/\[global\]/\[global\]\n        ldap server require strong auth = No/" /etc/samba/smb.conf

# Change the AD Administrator password in a way where the password doesn't
# show up in plaintext in the output.
RUN set -x \
  && if [ -f /tmp/tmp_ad_passwords/ad_admin_pw ]; then \
       echo "Using AD admin password from tmp_ad_passwords/ad_admin_pw"; \
       AD_ADMIN_PW_FILE=/tmp/tmp_ad_passwords/ad_admin_pw; \
     else \
       echo "Using default insecure AD admin password from tmp_ad_passwords/ad_admin_pw.template"; \
       AD_ADMIN_PW_FILE=/tmp/tmp_ad_passwords/ad_admin_pw.template; \
     fi \
  && sed -i "s#AD_ADMIN_PW_FILE#$AD_ADMIN_PW_FILE#" /tmp/tmp_ad_passwords/change_ad_password.expect \
  && expect /tmp/tmp_ad_passwords/change_ad_password.expect \
  && rm -rf /tmp/tmp_ad_passwords \
  && apt-get -y purge expect \
  && apt-get -y autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Copy the TLS key pair
COPY tls/*.pem /var/lib/samba/private/tls/

EXPOSE 389
EXPOSE 636

COPY etc/container/ /etc/container/
ENTRYPOINT ["/etc/container/samba-entrypoint.sh", "interactive"]

# Use 'docker inspect <name>' to find the volume files on the host.
# <name> is the value of the --name parameter when invoking docker run.
VOLUME /var/lib/samba
