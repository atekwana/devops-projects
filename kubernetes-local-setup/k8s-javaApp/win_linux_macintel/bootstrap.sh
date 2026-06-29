#!/bin/bash
## Common setup for all nodes (master and workers)
## Tested on ubuntu/jammy64 (Ubuntu 22.04)
## Kubernetes v1.30 with containerd runtime

# Kubernetes requires swap to be disabled
echo "[TASK 1] Disable and turn off SWAP"
sed -i '/swap/d' /etc/fstab
swapoff -a

# Disable ufw to allow k8s components to communicate freely
echo "[TASK 2] Stop and Disable firewall"
systemctl disable --now ufw >/dev/null 2>&1

# Enable IP forwarding and bridge traffic for k8s networking
echo "[TASK 3] Enable and Load Kernel modules"
cat >>/etc/modules-load.d/containerd.conf<<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# Enable IP forwarding and bridge traffic for k8s networking
echo "[TASK 4] Add Kernel settings"
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system >/dev/null 2>&1

# containerd is the container runtime used by k8s
# SystemdCgroup must be true to match kubelet's cgroup driver
echo "[TASK 5] Install containerd runtime"
apt update -qq >/dev/null 2>&1
apt install -qq -y containerd apt-transport-https >/dev/null 2>&1
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd >/dev/null 2>&1

# packages.cloud.google.com is deprecated — using new pkgs.k8s.io repo (MAKE SURE TO UPDATE)
echo "[TASK 6] Add apt repo for kubernetes"
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' > /etc/apt/sources.list.d/kubernetes.list
apt update -qq >/dev/null 2>&1

# Pin versions to avoid unintended upgrades
echo "[TASK 7] Install Kubernetes components (kubeadm, kubelet and kubectl)"
apt install -qq -y kubeadm=1.30.0-1.1 kubelet=1.30.0-1.1 kubectl=1.30.0-1.1 >/dev/null 2>&1

# Allows worker nodes to scp the join command from the master via password
echo "[TASK 8] Enable ssh password authentication"
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
systemctl reload sshd

# Password used by worker nodes to scp /joincluster.sh from master
echo "[TASK 9] Set root password"
echo -e "kubeadmin\nkubeadmin" | passwd root >/dev/null 2>&1
echo "export TERM=xterm" >> /etc/bash.bashrc

# Allows nodes to resolve each other by hostname
cat >>/etc/hosts<<EOF
192.168.33.2   kmaster.example.com     kmaster
192.168.33.3   kworker1.example.com    kworker1
192.168.33.4   kworker2.example.com    kworker2
EOF
