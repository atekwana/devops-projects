#!/bin/bash
###KUBENODE 2###

# NOTE: Disable swap (required by Kubernetes kubelet)
# Swap must be OFF because kubelet requires predictable memory management and does not support swap
# This disables swap immediately and removes it from fstab so it stays disabled after reboot
# Reference: https://kubernetes.io/docs/setup/production-environment/container-runtimes/
sudo swapoff -a && sudo sed -i '/swap/d' /etc/fstab
echo "======== QUALITY GATE(1) --> SWAP DISABLED ========!"

# NOTE: System Settings (required for Kubernetes networking)
# Enables kernel modules and sysctl settings required for container networking:
# - overlay: supports OverlayFS used by container runtimes (filesystem layering for containers)
# - br_netfilter: allows bridged IPv4/IPv6 traffic to be processed by iptables (required for Kubernetes networking)
# - ip_forward: enables packet forwarding between network interfaces (required for pod-to-pod networking)
# Reference: https://kubernetes.io/docs/setup/production-environment/container-runtimes/
# Reference: https://kubernetes.io/docs/concepts/cluster-administration/networking/
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
lsmod | grep br_netfilter
lsmod | grep overlay
echo "======== QUALITY GATE(2) --> KERNEL MODULES + SYSCTL CONFIGURED ========!"

# NOTE: Systemd is the init system on Ubuntu 22.04. Using cgroupfs alongside systemd
# creates two cgroup managers, causing instability under resource pressure.
# SystemdCgroup = true ensures containerd and kubelet use the same cgroup driver.
# containerd must be installed and configured before kubelet starts.
# Reference: https://kubernetes.io/docs/setup/production-environment/container-runtimes/
# Reference: https://github.com/containerd/containerd/blob/main/docs/cri/config.md
sudo apt update
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
echo "======== QUALITY GATE(3) --> CONTAINER RUNTIME (containerd) CONFIGURED ========!"

# NOTE: Install kubeadm, kubelet, and kubectl at a pinned version (v1.30).
# apt-mark hold prevents unintended upgrades that could break cluster compatibility.
# kubelet is enabled immediately as it must be running before the node joins the cluster.
# ufw allows port 6443 so this worker node can reach the master API server.
# Reference: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
KUBEVERSION=v1.30
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
sudo ufw allow 6443/tcp
echo "======== QUALITY GATE(4) --> KUBEADM + KUBELET + KUBECTL INSTALLED ========!"

# NOTE: Poll the master API server /healthz endpoint before attempting to join.
# The join command will fail if the API server is not yet ready or reachable.
# -s silences curl progress output. -k skips TLS verification (self-signed cert).
# cltjoincommand.sh is written by the master provisioner to the shared /vagrant directory.
# Reference: https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/
until curl -sk https://192.168.33.2:6443/healthz &>/dev/null; do
  echo "waiting for kubemaster API server..."
  sleep 10
done
echo "======== QUALITY GATE(5) --> KUBEMASTER API SERVER REACHABLE ========!"

# NOTE: Wait for the join command file to exist before executing it.
# The master writes cltjoincommand.sh only after its own QG(10) completes.
# Without this guard, the node may attempt to read a file that hasn't been written yet.
# Reference: https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/
until [ -f /vagrant/cltjoincommand.sh ]; do
  echo "waiting for join command from kubemaster..."
  sleep 5
done
echo "======== QUALITY GATE(6) --> JOIN COMMAND RECEIVED ========!"

/bin/bash /vagrant/cltjoincommand.sh
echo "======== QUALITY GATE(7) --> NODE JOINED CLUSTER ========!"
