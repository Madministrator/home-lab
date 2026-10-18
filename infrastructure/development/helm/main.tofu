# Development tofu/helm config
# Requires the tofu config in the parent directory to be applied first and
# a script run to fetch the kube config so the helm provider can run against
# the VM's K3s cluster.
#
# Uses Helm to configure resources in the K3s cluster, deploying applications
# as I desire.

terraform {
  required_providers {
    helm = {
      source  = "opentofu/helm"
      version = "3.3.0"
    }
  }
}

locals {
  kubeconfig_path        = abspath("${path.module}/../output/k3s.yaml")
  repository_config_path = abspath("${path.module}/helm_repository_config.yaml")
}

provider "helm" {
  repository_config_path = local.repository_config_path

  kubernetes = {
    # Helm needs the k3s credentials from the file the parent fetched
    config_path = local.kubeconfig_path
  }
}

# Check kube config file exists before attempting to use it for helm
resource "terraform_data" "kubeconfig_precondition" {
  input = local.kubeconfig_path

  lifecycle {
    precondition {
      condition     = fileexists(local.kubeconfig_path)
      error_message = "K3s kubeconfig not found at ${local.kubeconfig_path}. Apply the parent development configuration before planning Helm resources."
    }
  }
}

# Add Headlamp so I have a Kubernetes Web UI

# # now you should be able to install headlamp via helm
# helm install my-headlamp headlamp/headlamp --namespace kube-system

resource "helm_release" "k3s-headlamp" {
  name      = "k3s-headlamp"
  namespace = "kube-system"
  chart     = "headlamp/headlamp"

  create_namespace = false
  wait             = true
  atomic           = true
}

# TODO: create ingress so I don't have to port-forward to access headlamp

# TODO: create service account roles etc. so I have tokens to log into 
# headlamp with. Output said token from Tofu. 