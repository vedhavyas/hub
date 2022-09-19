FROM ubuntu:22.04
ENV container docker LANG=C.UTF-8

# Don't start any optional services except for the few we need.
RUN  find /etc/systemd/system \
     /lib/systemd/system \
     -path '*.wants/*' \
     -not -name '*journald*' \
     -not -name '*systemd-tmpfiles*' \
     -not -name '*systemd-user-sessions*' \
     -exec rm \{} \;

RUN  apt-get  update  && \
     apt-get  install  --no-install-recommends  -y \
       dbus systemd systemd-cron iproute2 wget sudo bash ca-certificates openssh-server && \
     apt-get  clean  && \
     rm  -rf  /var/lib/apt/lists/*  /tmp/*  /var/tmp/*

RUN  systemctl  set-default  multi-user.target
RUN  systemctl  mask  dev-hugepages.mount  sys-fs-fuse-connections.mount

COPY ssh /sbin/

STOPSIGNAL SIGRTMIN+3


#Change the configuration to use login with password
RUN sed -i 's/#\(PermitRootLogin\) \(prohibit-password\)/\1 yes/' /etc/ssh/sshd_config

#Add password to root user
RUN echo 'root:password' | chpasswd

#Create a sshd folder in /run path. This allow sshd to start from terminal.
RUN mkdir /run/sshd

EXPOSE 22
CMD ["/sbin/init", "--log-target=journal"]
