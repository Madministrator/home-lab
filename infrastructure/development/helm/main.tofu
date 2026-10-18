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
    kubernetes = {
      source = "opentofu/kubernetes"
    }
  }
}

locals {
  kubeconfig_path        = abspath("${path.module}/../output/k3s.yaml")
  repository_config_path = abspath("${path.module}/helm_repository_config.yaml")
}

provider "helm" {
  kubernetes = {
    # Helm needs the k3s credentials from the file the parent fetched
    config_path = local.kubeconfig_path
  }
  repository_config_path = local.repository_config_path
}

provider "kubernetes" {
  config_path = local.kubeconfig_path
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
## The ingress should make the application reachable at http://<VM IP address>/headlamp/ (the trailing slash is essential)
resource "helm_release" "k3s-headlamp" {
  name      = "k3s-headlamp"
  namespace = "kube-system"
  chart     = "headlamp/headlamp"

  create_namespace = false
  wait             = true
  atomic           = true

  values = [yamlencode({
    config = {
      baseURL = "/headlamp"
    }
    ingress = {
      enabled          = true
      ingressClassName = "traefik"
      hosts = [{
        host = ""
        paths = [{
          path = "/headlamp"
          type = "Prefix"
        }]
      }]
    }
  })]
}

# Create a service account for headlamp access to K3s resources (enables logging in with headlamp)
## After the binding applies, get headlamp token with `multipass k3s-kubectl -- create token headlamp-login -n kube-system`
resource "kubernetes_service_account_v1" "headlamp_login" {
  metadata {
    name      = "headlamp-login"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding_v1" "headlamp_login_binding" {
  metadata {
    name = "headlamp-login-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.headlamp_login.metadata[0].name
    namespace = kubernetes_service_account_v1.headlamp_login.metadata[0].namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
}
