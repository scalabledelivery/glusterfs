#!/bin/bash

set -m # Set manual job control

/usr/sbin/glusterd -N &

sleep 5s

if [ "${POD_NAME}" == "" ] || [ "${SERVICE_NAME}" == "" ] || [ "${NAMESPACE}" == "" ] || [ "${POD_COUNT}" == "" ]; then
  echo POD_NAME required.
  echo SERVICE_NAME required.
  echo NAMESPACE required.
  echo POD_COUNT required.
  exit 1
fi

POD_COUNT=$((${POD_COUNT} - 1))

if [ "$(hostname)" == "${POD_NAME}-0" ]; then
  echo $(date -u) - $(hostname) is the initializing node.
  
  GLUSTER_HOSTNAMES=`eval echo ${POD_NAME}-{0..${POD_COUNT}}.${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local`
  
  for gluster_hostname in ${GLUSTER_HOSTNAMES}; do
    echo $(date -u) - $(hostname) - Peering with ${gluster_hostname}
    while ! gluster peer probe ${gluster_hostname}; do sleep 1s; done
  done
fi
# bring glusterd back to foreground
fg
