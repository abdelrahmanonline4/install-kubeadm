# CRI-O and Kubernetes Installation Guide on Ubuntu 22.04


## Step 1: Update System and Install Required Packages
```bash
sudo -i
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
```

## Step 2: Add CRI-O Repository
```bash
export OS=xUbuntu_22.04
export CRIO_VERSION=1.24
```

### Add the CRI-O Kubic repository
```bash
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" | \
    sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRIO_VERSION/$OS/ /" | \
    sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.list
```

### Import the GPG key for the CRI-O repository
```bash
curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION/$OS/Release.key | \
    sudo apt-key add -
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | \
    sudo apt-key add -
```

### Update package lists
```bash
sudo apt update
```

## Step 3: Install CRI-O
```bash
sudo apt install -y cri-o cri-o-runc
```

## Step 4: Install CNI Plugins for CRI-O
```bash
sudo apt install -y containernetworking-plugins
```

## Step 5: Configure CRI-O
Edit the CRI-O configuration file:
```bash
sudo vi /etc/crio/crio.conf
```
Ensure the following settings are included:
```ini
[crio]
# CRI-O reads its storage defaults from the containers/storage configuration file, /etc/containers/storage.conf
# Modify storage.conf if you want to change default storage for all tools that use containers/storage

# The "crio.runtime" table contains settings pertaining to the OCI runtime used and options for how to set up and manage the OCI runtime.
[crio.runtime]

# Path to the "root directory". CRI-O stores all of its data, including containers images, in this directory.
root = "/var/lib/crio"

# A necessary file for CRI-O to operate is the crio.conf file, which is typically located in /etc/crio.
# It is mandatory for this file to exist.

# The CRI-O container engine uses OCI runtime technology to provide a real Linux container runtime environment.
[crio.network]

# network_dir is where CRI-O will look for network configuration files
network_dir = "/etc/cni/net.d/"

# plugin_dirs is a list of directories where CNI plugin binaries are located
plugin_dirs = [
    "/usr/lib/cni",
    "/opt/cni/bin"
]

# Additional CRI-O settings can be set and customized according to your specific needs.

```
Restart CRI-O:
```bash
sudo systemctl restart crio
```

## Step 6: Install CRI-O Tools
```bash
sudo apt install -y cri-tools
sudo crictl --runtime-endpoint unix:///var/run/crio/crio.sock version
```

Enable command completion:
```bash
sudo su -
crictl completion > /etc/bash_completion.d/crictl
source ~/.bashrc
crictl
```

## Step 7: Install Kubernetes (kubeadm, kubelet, kubectl)
### Open necessary ports
```bash
sudo iptables -A INPUT -p tcp --dport 6443 -j ACCEPT
```

### Disable swap
```bash
sudo swapoff -a
sudo sed -i '/swap/s/^/#/' /etc/fstab
```

### Add Kubernetes repository
```bash
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | \
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | \
    sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
```

### Install Kubernetes components
```bash
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
```

### Enable IP forwarding
```bash
sudo sed -i '/^net.ipv4.ip_forward=/{h;s/=.*/=1/};${x;/^$/{s//net.ipv4.ip_forward=1/;H};x}' /etc/sysctl.conf
sudo sysctl -p
```

## Step 8: Initialize Kubernetes Cluster (Master Node)
```bash
kubeadm init --control-plane-endpoint "172.31.18.186:6443"  # to add first master node 
kubeadm init phase upload-certs --upload-certs
kubeadm token create --print-join-command --certificate-key <CERT_KEY> # done add master
u can copy token to add worker also 

```

### Set up Kubernetes configuration for the current user
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Install a CNI (Calico)
```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
kubectl patch storageclass local-path \
-p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

## Step 9: Join Worker Nodes
On each worker node, run the join command obtained from the master node:
```bash
kubeadm token create --print-join-command
```
Run the output command on the worker node.

## Step 10: Verify the Cluster
On the master node, check node status:
```bash
kubectl get nodes -o wide
```



<img width="1685" height="123" alt="image" src="https://github.com/user-attachments/assets/2053934f-ae29-4340-a8ca-175a3b814e7d" />


