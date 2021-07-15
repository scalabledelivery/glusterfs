# glusterfs
Status: `experimental + in-dev`

Gluster container built to run as a StatefulSet in Kubernetes.

An example of how to deploy this is in `manifests/deploy.yaml`.

Deploying this with 3 replicas will provide a replication factor of 3; while 6 or more will provide a replication factor of 3 as well as distribution of data.

The number of replicas must be divisible by 3.