# Development tofu config
# Uses multipass to setup an ubuntu VM (because the home server uses Ubuntu) 
# and then deploys a single K3s node to that VM. Deploying resources to the
# K3s cluster is executed using config in the ./helm directory.

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

# Run script to fetch K3s credentials from the VM so it's accessible for helm
resource "null_resource" "acquire_credentials" { # null_resource because I'm not creating anything here
  depends_on = [ multipass_instance.k3s_server ] # won't run the script until the VM is created

  provisioner "local-exec" {
    command = "${path.module}/scripts/fetch-config.sh -i k3s-server -s ${multipass_instance.k3s_server.ipv4[0]}"
  }
}