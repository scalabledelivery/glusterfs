#!/bin/bash
if ! [[ `hostname` =~ ([A-Za-z0-9_-]+)-([0-9]+)$ ]]; then
    echo "container hostnames must contain ordinals"
    exit 1
fi

# get base hostname and ordinal of this pod
HOSTNAME_ORDINAL=${BASH_REMATCH[2]}
HOSTNAME_BASE=${BASH_REMATCH[1]}

# get the namespace we're in as well as api token
NS=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
SA_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
KUBERNETES_CA_CERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# convenience function
kube_api(){ curl --silent --cacert "${KUBERNETES_CA_CERT}" --header "Authorization: Bearer ${SA_TOKEN}" https://kubernetes.default.svc.cluster.local${@}; }

if [ ! -d /export/brick0 ]; then
  echo WARNING: /export/brick0 does not exist
  echo WARNING: creating /export/brick0
  echo WARNING: you should not use ephemeral gluster storage in production
  mkdir -p /export/brick0
fi

# how many replicas are there of this service?
REPLICAS=$(kube_api /apis/apps/v1/namespaces/${NS}/statefulsets?fieldSelector=metadata.name=glusterfs | jq '.items[0].spec.replicas')
if [ ${REPLICAS} -lt 3 ]; then
  echo ERROR: minimum of 3 replicas is required
  exit 1
fi

# Set manual job control, because we want
# glusterd in the forground at the end of this
set -m
/usr/sbin/glusterd -l /dev/stdout -N &


# ordered list of nodes
NODES=$(kube_api /api/v1/namespaces/${NS}/pods?labelSelector=app=glusterfs | jq -r '.items[].metadata.name' | awk -F- '{print $2" "$0}' | sort -n | cut -f2 -d' ')



echo processing nodes in sets of 3
NODES_ALLOWED="" # these are nodes that match in a sets of three
NODE_SET="" # we use this to iterate sets of 3
NODE_CT=0 # counter for tracking
for node in ${NODES}; do
  NODE_SET="${NODE_SET} ${node}"
  NODE_CT=$((${NODE_CT} + 1))
  if [ ${NODE_CT} == 3 ]; then
      NODE_CT=0
      NODES_ALLOWED="${NODES_ALLOWED} ${NODE_SET}"
      NODE_SET=""
  fi
done

echo checking if $(hostname) is in set of 3
for node in ${NODE_SET}; do
  echo ${node}
  if [ "${node}" == "$(hostname)" ]; then
    echo this statefulset requires the replicas to be divisible by 3
    echo there are not enough nodes for ${node} to be used in the cluster
    exit 1
  fi
done

# glusterfs-0 should run the show
if [ ${HOSTNAME_ORDINAL} == 0 ]; then

  echo gluster peering in progress
  for i in ${NODES_ALLOWED}; do
    # skip adding self to pool
    if [ "${i}" == "${HOSTNAME}" ]; then
      continue
    fi

    # add other nodes to pool
    NODE=${i}.glusterfs.${NS}.svc.cluster.local
    echo ${NODE} 
    while ! gluster peer probe ${NODE}; do sleep 3s; done
  done
  gluster pool list
  echo gluster peering complete

  # are we creating a new volume
  if ! gluster volume info gfsvol; then
    VOLS=""
    for i in $(hostname).glusterfs.${NS}.svc.cluster.local $(gluster pool list | awk '{if($1 != "UUID" && $2 != "localhost") print $2}'); do
      VOLS=$(echo ${VOLS} ${i}:/export/brick0);
    done
    echo creating gfsvol
    echo DEBUG: ${VOLS}
    gluster volume create gfsvol replica 3 ${VOLS} force
  fi

  echo ensure gfsvol is started
  gluster volume start gfsvol
  gluster volume set gfsvol auth.allow 192.*.*.*,10.*.*.*,172.*.*.*

  # TODO: implement automated upscaling
fi

echo starting rpcbind and ganesha nfs server
/sbin/rpcbind -f -w &
/usr/bin/ganesha.nfsd -F -L /dev/stdout -f /etc/ganesha/ganesha.conf
