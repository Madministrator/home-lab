# Development tofu config
#
# Role: Use multipass to spin up ubuntu image (because the home server uses Ubuntu)
# and then run the same infrastructure steps on that ubuntu image that I would run
# on my Ubuntu server.
#
# Note: Eventually, I will move resources into a shared module so instructions can
# be reused between this dev tofu and the prod tofu. But first, I need to get dev
# in a working state before I start thinking about prod deployments
#
# Current Goal: Hello World Kubernetes equivalent running on a multipass VM

# After running `tofu apply` I should be able to run `multipass k3s-kubectl get nodes`
# to fetch the single node

terraform {
  required_providers {
    multipass = {
        # https://search.opentofu.org/provider/todoroff/multipass/latest
        source = "todoroff/multipass"
    }
  }
}

provider "multipass" {
  # Increase timeout for image downloads and initialization
  command_timeout = 600 
}

locals {
    # Creates a wrapper script for kubectl and installs K3s server
    # Note: "#cloud-config" is a header essential to have the VM interpret this as YAML
    k3s_cloud_init = <<-EOT
    #cloud-config
    package_update: true
    package_upgrade: true
    write_files:
      - path: /usr/local/bin/k3s-kubectl-wrapper
        permissions: '0755'
        content: |
          #!/bin/sh
          sudo k3s kubectl "$@"
    runcmd:
      - curl -sfL https://get.k3s.io | sh -
  EOT
}

# Create single node K3s server
resource "multipass_instance" "k3s_server" {
    name = "k3s-server"
    cpus = 2
    memory = "2G"
    disk = "10G"
    image = "jammy" # Ubuntu 22.04 LTS (TODO: how to declare latest?)

    cloud_init = local.k3s_cloud_init
}

# declare the wrapper script as an alias to simplify CLI commands
resource "multipass_alias" "kubectl" {
    name = "k3s-kubectl"
    instance = multipass_instance.k3s_server.name
    command = "/usr/local/bin/k3s-kubectl-wrapper"
}

# Output the node IP
output "cluster_nodes" {
  value = {
    server = multipass_instance.k3s_server.ipv4
  }
}