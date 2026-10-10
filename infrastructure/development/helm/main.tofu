# Development tofu/helm config
# Uses multipass to setup an ubuntu VM (because the home server uses Ubuntu) 
# and then deploys a single K3s node to that VM. Deploying resources to the
# K3s cluster is executed using config in the ./helm directory.

# Requires the tofu config in the parent directory to be applied first and
# a script run to fetch the kube config so the helm provider can run against
# the VM's K3s cluster.