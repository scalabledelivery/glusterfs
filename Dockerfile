FROM centos:centos8
RUN dnf install -y centos-release-gluster
RUN dnf install -y glusterfs-server nfs-utils which
VOLUME /data /var/lib/glusterd /glusterfs
EXPOSE 111 111/udp 24007 24009 49152
COPY ./entrypoint.sh /entrypoint.sh
ENTRYPOINT bash /entrypoint.sh
