# When an ubuntu VM initializes a K3s cluster, the cluster 
# kube config lives in /etc/rancher/k3s/k3s.yaml. However, the
# server address in k3s.yaml will be 127.0.0.1, when we need it
# to be the server address of the VM (because the helm apply step)
# runs on the host machine.  That will be passed in as a parameter
# by tofu.