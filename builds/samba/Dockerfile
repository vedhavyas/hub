FROM ubuntu:latest
ENV TZ=UTC
RUN apt update -yqq
RUN apt install -yqq --no-install-recommends samba ca-certificates openssl tzdata samba-libs
RUN apt install -y libreadline-dev git build-essential libattr1-dev libblkid-dev autoconf python-dev python-dnspython libacl1-dev gdb pkg-config libpopt-dev libldap2-dev dnsutils acl attr libbsd-dev docbook-xsl libcups2-dev libgnutls28-dev tracker libtracker-sparql-2.0-dev libpam0g-dev libavahi-client-dev libavahi-common-dev bison flex avahi-daemon liblmdb-dev libjansson-dev libgpgme-dev libarchive-dev libparse-yapp-perl libicu-dev python3-pyasn1 python3-markdown python3-dnspython libtasn1-bin
RUN echo $TZ | tee /etc/timezone
EXPOSE 139/tcp 445/tcp
CMD /usr/sbin/smbd --daemon --foreground --no-process-group --log-stdout --debuglevel=3 --configfile=/etc/samba/smb.conf
