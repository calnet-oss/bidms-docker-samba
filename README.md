## Purpose

This container image runs a [Samba](http://www.samba.org/) Active Directory
Domain Controller and exposes the TLS directory port on port 636.  This
image is not used in production by the author but rather is used as an
Active Directory server in development and early-testing environments.  With
some hardening, it has potential for production deployments.  It can also be
used as a [Kerberos](http://web.mit.edu/kerberos/) Key Distribution Center
(KDC), although you'll have to
[EXPOSE](https://docs.docker.com/engine/reference/builder/#expose) more
ports in the [Dockerfile](https://docs.docker.com/engine/reference/builder/)
so that your Kerberos clients can connect to the KDC.

The author does not currently publish the image in any public container
repository but a script, described below, is provided to easily create your
own image.

## License

The source code, which in this project is primarily shell scripts and the
Dockerfile, is licensed under the [BSD two-clause license](LICENSE.txt).

## Building the container image

Copy `config.env.template` to `config.env` and edit to set config values.

Create an `ad_admin_pw` file with the Active Directory Administrator
password in it.

Make it only readable by the owner:
```
chmod 600 ad_admin_pw

Create your TLS certs in `imageFiles/tls`.  You need a ca.pem (CA public
key), an unencrypted key.pem (private key) and a cert.pem (public key).  If
you want to generate a self-signed certificate, you can use the
[generateTLSCert.sh](generateTLSCert.sh) script.

Update your Debian image:
```
./updateDebian.sh
```

Make sure the `HOST_SAMBA_DIRECTORY` directory specified in `config.env`
does not exist yet on your host machine (unless you're running
`buildImage.sh` subsequent times and want to keep your existing directory)
so that the build script will initialize your directory.

Build the container image:
```
./buildImage.sh
```

The domain Administrator password will be set to the password you have in
the `ad_admin_pw` file unless you have set `SKIP_ADMIN_PASSWORD_CHANGE=1` in
`config.env`.  If you have done that, then you should run the container and
reset the password manually with `samba-tool user setpassword
Administrator`.  Otherwise, you'll have the insecure, publicly-known default
password.

You'll need the `expect` program installed for `buildImage.sh` to be able to
set the domain Administrator password.

## Running

To run the container interactively (which means you get a shell prompt):
```
./runContainer.sh
```

Or to run the container detached, in the background:
```
./detachedRunContainer.sh
```

If everything goes smoothly, the container should expose port 636, the
Active Directory SSL port.  This port is redirected to a port on the host,
where the host port number is specified in `config.env` as
`LOCAL_DIR_SSL_PORT`.

You can then use your favorite directory client to connect to it.

As an example, if you have the [OpenLDAP](http://www.openldap.org/)
`ldapsearch` client installed: Run the `./dumpAD.sh` script to dump the list
of distinguished names in the directory.

If running interactively, you can exit the container by exiting the bash
shell.  If running in detached mode, you can stop the container with: 
```
docker stop bidms-samba
```
(You may replace docker commands with podman if you prefer.)

To inspect the running container from the host:
```
docker inspect bidms-samba
```

To list the running containers on the host:
```
docker ps
```

## Directory Persistence

The container runtime will mount the host directory specified in
`HOST_SAMBA_DIRECTORY` from `config.env` within the container as
`/var/lib/samba` and this is how the directory is persisted across container
runs.

As mentioned in the build image step, the `buildImage.sh` script will
initialize an empty directory as long as the `HOST_SAMBA_DIRECTORY`
directory doesn't exist yet on the host at the time `buildImage.sh` is run. 
Subsequent runs of `buildImage.sh` will not re-initialize the directory if
the directory exists.

If you plan on running the image on hosts separate from the machine you're
running the `buildImage.sh` script on then you'll probably want to let
`buildImage.sh` initialize a directory and then copy the
`HOST_SAMBA_DIRECTORY` to all the machines that you will be running the
image on.  When copying, be careful about preserving file permissions.

## Kerberos

This section is only relevant if you only want to interact directly with the
Kerberos KDC that Samba provides.  (As a side note, you can use `samba-tool`
to set passwords and such, so in most cases, interacting with Kerberos is
not required.)

In the container, to get started with a Kerberos client, run this (replace
EXAMPLE.COM if you configured with a different domain):
```
kinit Administrator@EXAMPLE.COM
```

You can verify that it worked with:
```
klist
```

The Kerberos configuration file that the clients uses is `/etc/krb5.conf`.

If you're wanting to use remote Kerberos clients, you'll need to EXPOSE some
KDC ports.  You may need to EXPOSE the DNS port as well and configure your
client machines to use the container's DNS server.  Kerberos relies on
Kerberos-specific entries that are in Samba's DNS server.  It's possible to
configure external DNS servers (such as BIND9 servers) with these Kerberos
entries, but that's out of scope here.  You can use `/etc/krb5.conf` in the
container as a template for the Kerberos configuration for your remote
Kerberos client machines.
