# My Home lab

I've previously used some simple GUI based software to setup a home server on an old laptop to host my digital media collection. However, all of it was managed in-app using pre-set controls in a very naive implementation. In the event of a catastrophic failure in which I need to replace home server hardware, I would have to start over from scratch. In my professional career as a Software Engineer working on cloud based server applications, I have developed skills working with terraform/openTofu, helm, and other infrastructure-as-code (IaC) solutions to manage both applications and Kubernetes clusters.

This project is the continued application and expansion of my professional skills as a software engineer to define a home server using IaC so that I can easily setup, teardown, monitor, and experiment with a home server without being concerned about losing settings. Additionally, defining IaC in this way will make it easier to recover my server should the old laptop server encounter physical device failure, or I simply upgrade to newer hardware.

## Initial Scope
The initial scope of the server is to recreate my server with everything I currently have in a non-IaC setup.

- [Jellyfin](https://jellyfin.org/) for media streaming (excluding music)
- [Navidrome](https://www.navidrome.org/) for music streaming
- Grafana for monitoring both the applications and the hardware itself (data retention for 1 month)
- Headlamp as a K8s dashboard
- Everything runs as a docker image on a Kubernetes cluster

## Wishlist
- Create my own server applications and host them on the server for fun.
- [Immich](https://immich.app/) for photo backups
- Automated deployment or rollbacks using GitHub Action runners
- A separate K8s cluster for dev environment, which means I can experiment on whatever I feel like without affecting applications other members of my household may wish to use.

# Design

There are two rules for this project:
1. Everything I use must be free and open source so that I am free to use my server however I want and nobody can withhold my server from me using a subscription tier.
2. This project is for my own self-improvement, I will not use AI to generate any code. Doing it myself is the best way for me to learn from this project.

## Infrastructure Technologies (and why)

### Multipass
[Multipass](https://canonical.com/multipass) is Canonical's lightweight VM manager for Linux, Windows, and macOS. It spins up Ubuntu instances in seconds, and I initially setup my home server with Ubuntu Server. So using multipass will allow me to test the server configuration on my local machine. If I change my home server to run ProxMox VE instead of Ubuntu (for it's well-known compatibility with terraform/OpenTofu)

### OpenTofu
[OpenTofu](https://opentofu.org/docs) will define resources on my server with IaC. It's a free and open source alternative to terraform, which I am already familiar with in my professional work. Additionally, it is cloud provider agnostic, should I want to create a cloud server based on what I build with this project.

### Kubernetes
[Kubernetes](https://kubernetes.io/) will manage my application containers, in particular it will restart the applications in the event that they crash, something my previous setup lacked. It is also a very widely adopted container manager for good reason, and just like OpenTofu it is cloud provider agnostic. In my simple home server where I am the primary user of all services on the server, high availability is not a concern and I will be using a single-node topology.

I will specifically be using [K3s](https://k3s.io/) to run the Kubernetes cluster. I compared K3s to other alternatives such as [minikube](https://minikube.sigs.k8s.io/docs/), and I chose K3s for the following reasons:
- Very lightweight, K3s is a single sub-100MB binary.
- It's built for IoT hardware, which means my server running on an old laptop will have more than enough resources.
- Tools like minikube are explicitly for developer learning environments, K3s is production-grade. I intend to use my home server like a production environment.

### Helm
[Helm](https://helm.sh/docs/) is a package manager for Kubernetes. It will manage all the configuration necessary to deploy applications in the Kubernetes cluster. Especially convenient because it has an [OpenTofu provider](https://search.opentofu.org/provider/opentofu/helm/latest) to make configuring the cluster easy as part of the tofu config.

### Grafana
[Grafana](https://grafana.com/oss/grafana/) is but one application in a library of free and open source applications for monitoring purposes, which means if I want to expand my monitoring stack I have easily compatible options in that ecosystem. Grafana also comes with thorough documentation and tutorials, making it well suited for a project that is as much about learning as it is about creating a home server.

# Getting Started

## Install tools
1. [Install Multipass](https://canonical.com/multipass/install)
2. [Install OpenTofu](https://opentofu.org/docs/intro/install/)
3. [Install Kubectl](https://kubernetes.io/docs/tasks/tools/)
4. [Install Helm](https://helm.sh/docs/intro/install)

## Local development
For experimentation purposes, a multipass Ubuntu VM is used to experiment with configurations before applying changes to the actual cluster. These commands are written to be run from the repo root.

### Step 1. setup the VM with a K3s cluster
```zsh
tofu init -chdir="./infrastructure/development
tofu apply -chdir="./infrastructure/development --auto-approve
```
Make note of the VM's IP address, which is output after the apply.
To confirm the tofu plan applied successfully, you should see a single node when you run `multipass k3s-kubectl get nodes`.

### Step 2. Apply helm config in the K3s cluster
```zsh
helm repo update --repository-config infrastructure/development/helm/helm_repository_config.yaml
tofu init -chdir="./infrastructure/development/helm
tofu apply -chdir="./infrastructure/development/helm --auto-approve
```

### Step 3. Verify results
Once the helm infrastructure is in place, you should be able to reach a [headlamp](https://headlamp.dev/) application on `http://<VM IP>/headlamp/`
To get a token headlamp can use to manage the K3s cluster, run `multipass k3s-kubectl -- create token headlamp-login -n kube-system | pbcopy` and 
paste the token into the web UI.

### Tear down development
Because everything is built on the VM, asking tofu to delete the VM will automatically clean up all subsequent stages.
```zsh
tofu destroy -chdir="./infrastructure/development --auto-approve
```
