#!/bin/bash
set -e

# Step 1: Update System and Install Required Packages
sudo apt update -y
sudo apt install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common

# Step 2: Add CRI-O Repository
export OS=xUbuntu_22.04
export CRIO_VERSION=1.24

echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" | \
    sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list

echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRIO_VERSION/$OS/ /" | \
    sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.list

curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION/$OS/Release.key | \
    sudo apt-key add -

curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | \
    sudo apt-key add -

sudo apt update -y

# Step 3: Install CRI-O
sudo apt install -y cri-o cri-o-runc

# Step 4: Install CNI Plugins for CRI-O
sudo apt install -y containernetworking-plugins
sudo systemctl restart crio

# Step 5: Configure CRI-O
cat <<EOF | sudo tee /etc/crio/crio.conf
[crio.runtime]
root = "/var/lib/crio"

[crio.network]
network_dir = "/etc/cni/net.d/"
plugin_dirs = [
    "/usr/lib/cni",
    "/opt/cni/bin"
]
EOF

sudo systemctl enable --now crio

# Step 6: Install CRI-O Tools
sudo apt install -y cri-tools
sudo crictl --runtime-endpoint unix:///var/run/crio/crio.sock version

# Enable crictl completion
sudo crictl completion > /etc/bash_completion.d/crictl
source ~/.bashrc

# Step 7: Install Kubernetes (kubeadm, kubelet, kubectl)
sudo iptables -A INPUT -p tcp --dport 6443 -j ACCEPT

sudo swapoff -a
sudo sed -i '/swap/s/^/#/' /etc/fstab

sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | \
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | \
    sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

# Enable IP forwarding
sudo sed -i '/^net.ipv4.ip_forward=/{h;s/=.*/=1/};${x;/^$/{s//net.ipv4.ip_forward=1/;H};x}' /etc/sysctl.conf
sudo sysctl -p
