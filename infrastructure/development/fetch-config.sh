#!/usr/bin/env bash
set -euo pipefail

# When an ubuntu VM initializes a K3s cluster, the cluster 
# kube config lives in /etc/rancher/k3s/k3s.yaml. However, the
# server address in k3s.yaml will be 127.0.0.1, when we need it
# to be the server address of the VM (because the helm apply step)
# runs on the host machine.  That will be passed in as a parameter
# by tofu.

# Step 0: Input validation
while getopts ":i:s:" option; do
  case $option in
    i)
      instance="$OPTARG"
      ;;
    s)
      server_address="$OPTARG"
      ;;
    *)
      echo "Usage: $0 [-i instance_name] [-s server_address]"
      exit 1
      ;;
  esac
done

echo "Instance name: $instance"
echo "Server address: $server_address"

# Step 1: Check that the K3s cluster is live
timeout_seconds=10
deadline=$((SECONDS + timeout_seconds))
while (( SECONDS < deadline )); do
  # Require at least one node, then wait briefly for all nodes to become Ready.
  nodes=$(
    multipass exec "$instance" -- sudo k3s kubectl get nodes --no-headers 2>/dev/null
  ) || nodes=""

  echo "nodes = $nodes"
  if [ -n "$nodes" ]; then
    echo "K3s is ready."
    break
  fi

  sleep 5
done

if (( SECONDS >= deadline )); then
  echo "Timed out waiting for K3s node readiness." >&2
  multipass exec "$instance" -- sudo k3s kubectl get nodes >&2 || true
  exit 1
fi

# Step 2: Fetch the kube config from the VM
file_name="./output/k3s.yaml"
multipass exec k3s-server -- sudo cat /etc/rancher/k3s/k3s.yaml > $file_name
chmod 600 $file_name
echo "Fetched K3s.yaml"

# Step 3: replace instances of 127.0.0.1 from the kube config with the value passed in from tofu
sed -i '' "s|127.0.0.1|$server_address|g" "$file_name"
echo "Substituted 127.0.0.1 with $server_address"
