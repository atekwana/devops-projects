#!/bin/bash
###KUBEMASTER###

# NOTE: Disable swap (required by Kubernetes kubelet)
# Swap must be OFF because kubelet requires predictable memory management and does not support swap
# This disables swap immediately and removes it from fstab so it stays disabled after reboot
# Reference: https://kubernetes.io/docs/setup/production-environment/container-runtimes/
sudo swapoff -a && sudo sed -i '/swap/d' /etc/fstab


# NOTE: System Settings (required for Kubernetes networking)
# Enables kernel modules and sysctl settings required for container networking:
# - overlay: supports OverlayFS used by container runtimes (filesystem layering for containers)
# - br_netfilter: allows bridged IPv4/IPv6 traffic to be processed by iptables (required for Kubernetes networking)
# - ip_forward: enables packet forwarding between network interfaces (required for pod-to-pod networking)

# NOTE: Reference(s) (kernel modules + Kubernetes networking requirements):
# https://kubernetes.io/docs/setup/production-environment/container-runtimes/
# https://kubernetes.io/docs/concepts/cluster-administration/networking/
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

#sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

# NOTE:Systemd is the init system on Ubuntu 22.04. Using cgroupfs alongside systemd
# Sreates two cgroup managers, causing instability under resource pressure.
# SystemdCgroup = true ensures containerd and kubelet use the same cgroup driver.
# Reference: https://kubernetes.io/docs/setup/production-environment/container-runtimes/
sudo apt update
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd


#Installing Kubeadm, Kubelet & Kubectl#
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

IPADDR=192.168.33.2
POD_CIDR=10.244.0.0/16
NODENAME=kubemaster

# NOTE:This flag controls the address the API server advertises to other cluster members, 
# and is also the address used to construct the kubeadm join line — so both the cert and 
# the join command will consistently reference 192.168.33.2. Kubernetes
if [ ! -f /etc/kubernetes/admin.conf ]; then
  kubeadm init --control-plane-endpoint=$IPADDR \
    --apiserver-advertise-address=$IPADDR \
    --pod-network-cidr=$POD_CIDR \
    --node-name $NODENAME \
    --ignore-preflight-errors Swap &>> /tmp/initout.log
  echo "SUCCESS -- MOVING ON!"

  # fail fast check
  if [ $? -ne 0 ]; then
    echo "ERROR --- KUBEADM FAILED!"
    exit 1
  fi
else
  echo "SUCCESS --- MOVING ON!"
fi

# setup kubeconfig
sed -i 's/\r//g' /vagrant/set-kubeconfig.sh
sudo /bin/bash /vagrant/set-kubeconfig.sh

# ensure kubectl always uses correct cluster context
export KUBECONFIG=/etc/kubernetes/admin.conf

# wait for Kubernetes API + cluster readiness (node registration)
until kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes &>/dev/null; do
  echo "waiting for Kubernetes API server..."
  sleep 10
done


# NOTE: Only run kubeadm/kubectl operations AFTER API server is reachable
# (confirmed via kubectl get nodes loop). Otherwise commands may fail.
# Join nodes together
# Reference: kubeadm init docs — post-init operations require API server to be reachable
# https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/
# 
kubeadm token create --print-join-command > /vagrant/cltjoincommand.sh

# install CNI (Calico)
KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/calico.yaml
