## Purpose

This Docker image runs a Samba Active Directory Domain Controller and
exposes the TLS directory port on port 636.  This image is not used in
production by the author but rather is used as an Active Directory server in
development and early-testing environments.  With some hardening, it has
potential for production deployments.  It can also be used as a Kerberos Key
Distribution Center (KDC), although you'll have to EXPOSE more ports in the
Dockerfile so that your Kerberos clients can connect to the KDC.

## License

The source code, which in this project is primarily shell scripts and the
Dockerfile, is licensed under the [BSD two-clause license](LICENSE.txt).

## Building the Docker image

Copy `config.env.template` to `config.env` and edit to set config values.

Create `imageFiles/tmp_ad_passwords/ad_admin_pw` file and set an Active
Directory Administrator password.

Make sure it's only readable by the owner:
```
chmod 600 imageFiles/tmp_ad_passwords/ad_admin_pw
```

Update your Debian image:
```
./updateDebian.sh
```

Make sure the `HOST_SAMBA_DIRECTORY` directory specified in `config.env`
does not exist yet on your host machine (unless you're running buildImage.sh
subsequent times and want to keep your existing directory) so that the build
script will initialize your directory.

Build the container image:
```
./buildImage.sh
```

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
Active Directory SSL port.

You can then use your favorite directory client to connect to it.

As an example, if you have the [OpenLDAP](http://www.openldap.org/)
`ldapsearch` client installed: Run the `./dumpAD.sh` script to dump the list
of distinguished names in the directory.

If running interactively, you can exit the container by exiting the bash
shell.  If running in detached mode, you can stop the container with: ```
docker stop bidms-samba ```

To inspect the running container from the host:
```
docker inspect bidms-samba
```

To list the running containers on the host:
```
docker ps
```

## Directory Persistence

Docker will mount the host directory specified in `HOST_SAMBA_DIRECTORY`
from config.env within the container as `/var/lib/samba` and this is how the
directory is persisted across container runs.

As mentioned in the build image step, the `buildImage.sh` script will
initialize an empty directory as long as the `HOST_SAMBA_DIRECTORY`
directory doesn't exist yet on the host at the time `buildImage.sh` is run. 
Subsequent runs of `buildImage.sh` will not re-initialize the directory if
the directory exists.

If you plan on running the image on hosts separate from the machine you're
running the 'buildImage.sh` script on then you'll probably want to let
`buildImage.sh` initialize a directory and then copy the
`HOST_SAMBA_DIRECTORY` to all the machines that you will be running the
image on.  When copying, be careful about preserving file permissions.

## Kerberos

This section is only relevant if you only want to interact directly with the
Kerberos KDC that Samba provides.  (As a side note, you can use samba-tool
to set passwords and such, so in most cases, interacting with Kerberos is
not required.)

In the container, to get started with a Kerberos client, run this (replace
EXAMPLE.COM if you configured with a different domain):
```
kinit Administrator@EXAMPLE.COM
```

The password is the one you provided in the
`imageFiles/tmp_ad_passwords/ad_admin_pw` file.

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
