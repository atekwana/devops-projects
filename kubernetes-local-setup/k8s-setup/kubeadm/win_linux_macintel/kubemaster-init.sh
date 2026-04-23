#!/bin/bash
###KUBEMASTER###

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
# kubelet is enabled immediately as it must be running before kubeadm init.
# ufw allows port 6443 so worker nodes can reach the API server.
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

# NOTE: kubeadm init bootstraps the control plane.
# --control-plane-endpoint and --apiserver-advertise-address are set to the static
# private IP so that both the TLS cert and the join command consistently reference
# the correct address for worker nodes.
# --pod-network-cidr=10.244.0.0/16 matches the Calico CNI default range applied later.
# --ignore-preflight-errors Swap is safe here because swap was disabled in QG(1).
# Guard clause prevents re-init if admin.conf already exists (idempotent on reprovision).
# Reference: https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/
IPADDR=192.168.33.2
POD_CIDR=10.244.0.0/16
NODENAME=kubemaster

if [ ! -f /etc/kubernetes/admin.conf ]; then
  kubeadm init --control-plane-endpoint=$IPADDR \
    --apiserver-advertise-address=$IPADDR \
    --pod-network-cidr=$POD_CIDR \
    --node-name $NODENAME \
    --ignore-preflight-errors Swap &>> /tmp/initout.log

  if [ $? -ne 0 ]; then
    echo "======== QUALITY GATE(5) ERROR --> KUBEADM INIT FAILED ========!"
    exit 1
  fi
fi
echo "======== QUALITY GATE(5) --> CONTROL PLANE INITIALISED ========!"

# NOTE: kubeconfig must be distributed to both root and vagrant users so kubectl
# works correctly regardless of which user context subsequent commands run under.
# set-kubeconfig.sh handles both /root/.kube/config and /home/vagrant/.kube/config.
# KUBECONFIG is also exported for the remainder of this script session.
# Reference: https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/
sed -i 's/\r//g' /vagrant/set-kubeconfig.sh
sudo /bin/bash /vagrant/set-kubeconfig.sh
export KUBECONFIG=/etc/kubernetes/admin.conf
echo "======== QUALITY GATE(6) --> KUBECONFIG DISTRIBUTED ========!"

# NOTE: Poll the API server before issuing any kubectl commands.
# The API server may still be starting up immediately after kubeadm init.
# &>/dev/null suppresses all output — we only care about the exit code here.
# Reference: https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/
until kubectl --kubeconfig=$KUBECONFIG get nodes &>/dev/null; do
  echo "waiting for Kubernetes API server..."
  sleep 5
done
echo "======== QUALITY GATE(7) --> API SERVER REACHABLE ========!"

# NOTE: CNI MUST be applied before waiting for node Ready status.
# Without a CNI plugin, coredns pods stay Pending and the node remains NotReady indefinitely.
# Calico is applied here immediately after the API server is confirmed reachable.
# The pod-network-cidr passed to kubeadm init (10.244.0.0/16) must match the Calico config.
# Reference: https://kubernetes.io/docs/concepts/cluster-administration/networking/
# Reference: https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart
KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/calico.yaml
echo "======== QUALITY GATE(8) --> CNI (Calico) INSTALLED ========!"

# NOTE: Wait for the node to reach Ready state before generating the join command.
# The node will only become Ready once the CNI plugin is running and has configured
# the pod network. 2>/dev/null suppresses API errors during calico startup.
# Reference: https://kubernetes.io/docs/concepts/architecture/nodes/#node-status
until kubectl --kubeconfig=$KUBECONFIG get nodes --no-headers 2>/dev/null | grep -i " ready"; do
  echo "waiting for Kubernetes cluster..."
  sleep 10
done
echo "======== QUALITY GATE(9) --> NODE READY ========!"

# NOTE: The join command is written to the shared /vagrant directory so worker node
# provisioning scripts can read and execute it without any manual copy step.
# Token is generated after node Ready to ensure the cluster is fully operational.
# Reference: https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/
kubeadm token create --print-join-command > /vagrant/cltjoincommand.sh
echo "======== QUALITY GATE(10) --> JOIN COMMAND GENERATED ========!"
