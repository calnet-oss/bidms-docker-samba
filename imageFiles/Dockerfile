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
FROM bidms/debian_base:bookworm

ARG APT_PROXY_URL=
RUN if [ ! -z "$APT_PROXY_URL" ]; then echo "Acquire::http::Proxy \"$APT_PROXY_URL\";" > /etc/apt/apt.conf.d/00aptproxy; else echo "not using apt proxy"; fi

RUN set -x \
  && export DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
  && apt-get dist-upgrade -y \
  && apt-get install -y bind9-host dnsutils telnet krb5-user \
       samba samba-ad-dc samba-ad-provision samba-dsdb-modules \
       winbind ldb-tools tdb-tools \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/*

COPY root/ /root/

# Samba AD Domain Controller set up
ARG AD_REALM=example.com
ARG AD_DOMAIN=example
ARG AD_DC_HOSTNAME=dc1
ARG AD_BASE=dc=example,dc=com
RUN set -x \
  && mv /etc/samba/smb.conf /etc/samba/smb.conf.ORIG \
  && mv /etc/krb5.conf /etc/krb5.conf.ORIG

ARG BACKEND_STORE_SIZE=4Gb
RUN echo "#!/bin/sh" > /var/lib/samba/samba-domain-provision.sh \
  && echo 'rm -f /etc/samba/smb.conf && \\' \
  && echo "samba-tool domain provision \
       --backend-store=mdb \
       --backend-store-size=\"$BACKEND_STORE_SIZE\" \
       --use-rfc2307 \
       --realm=\"$AD_REALM\" \
       --domain=\"$AD_DOMAIN\" \
       --server-role=dc \
       --dns-backend=\"SAMBA_INTERNAL\" \
       --adminpass=Passw0rd \
       --host-name=\"$AD_DC_HOSTNAME\" \
       --option=\"log level=1\" \
       --option=\"log file=/var/log/samba/samba.log\" && \\" >> /var/lib/samba/samba-domain-provision.sh \
  && echo 'samba-tool domain passwordsettings set --max-pwd-age=0 && \\' >> /var/lib/samba/samba-domain-provision.sh \
  && chmod 755 /var/lib/samba/samba-domain-provision.sh

# Add additional indexes
# searchFlags, the index indicator attribute, is documented:
# https://msdn.microsoft.com/en-us/library/ms679765(v=vs.85).aspx
RUN sed -i "s/AD_BASE/$AD_BASE/" /root/indexModifications.ldif \
  && echo 'ldbmodify -H /var/lib/samba/private/sam.ldb \
       /root/indexModifications.ldif \
       --option="dsdb:schema update allowed"=true && \\' >> /var/lib/samba/samba-domain-provision.sh

COPY etc/krb5.conf /etc

RUN set -x \
  && AD_REALM_UPPER=$(echo "$AD_REALM"|tr '[:lower:]' '[:upper:]') \
  && AD_REALM_LOWER=$(echo "$AD_REALM"|tr '[:upper:]' '[:lower:]') \
  && sed -i "s/EXAMPLE.COM/${AD_REALM_UPPER}/" /etc/krb5.conf \
  && sed -i "s/example.com/${AD_REALM_LOWER}/" /etc/krb5.conf

RUN echo 'sed -i "s/\[global\]/\[global\]\\n        ldap server require strong auth = No/" /etc/samba/smb.conf && \\' >> /var/lib/samba/samba-domain-provision.sh
RUN echo 'mv /etc/samba/smb.conf /var/lib/samba && ln -fs /var/lib/samba /etc/samba/smb.conf' >> /var/lib/samba/samba-domain-provision.sh

# smb.conf created later in /var/lib/samba by the samba-domain-provision.sh script
RUN ln -fs /var/lib/samba/smb.conf /etc/samba/smb.conf

RUN set -x \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Copy the TLS key pair
COPY tls/*.pem /var/lib/samba/private/tls/
RUN chmod 600 /var/lib/samba/private/tls/key.pem

EXPOSE 389
EXPOSE 636

COPY etc/container/ /etc/container/
ENTRYPOINT ["/etc/container/samba-entrypoint.sh", "interactive"]

# Use 'docker inspect <name>' to find the volume files on the host.
# <name> is the value of the --name parameter when invoking docker run.
VOLUME /var/lib/samba
