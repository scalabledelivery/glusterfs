FROM centos:centos8
RUN dnf install -y centos-release-gluster centos-release-nfs-ganesha30 
RUN dnf install -y nfs-ganesha-gluster glusterfs-server nfs-utils which jq
VOLUME /data /var/lib/glusterd /glusterfs
EXPOSE 111 111/udp 24007 24009 49152
COPY ./ganesha.conf /etc/ganesha/ganesha.conf
COPY ./entrypoint.sh /entrypoint.sh
ENTRYPOINT bash /entrypoint.sh
