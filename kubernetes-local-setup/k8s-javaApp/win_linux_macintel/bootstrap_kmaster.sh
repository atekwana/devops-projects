#!/bin/bash
## Master node initialization script
## Runs after bootstrap.sh completes on kmaster only

# Pre-pull control plane images (etcd, apiserver, scheduler, etc.)
echo "[TASK 1] Pull required containers"
kubeadm config images pull >/dev/null 2>&1

# --apiserver-advertise-address: IP of kmaster on the private network
# --pod-network-cidr: required by Calico CNI (must be 192.168.0.0/16)
# Output saved to kubeinit.log for debugging
echo "[TASK 2] Initialize Kubernetes Cluster"
kubeadm init --apiserver-advertise-address=192.168.33.2 --pod-network-cidr=192.168.0.0/16 >> /root/kubeinit.log 2>&1

# Calico CNI provides pod networking and network policy
# v3.27.3 — tested with k8s 1.30
echo "[TASK 3] Deploy Calico network"
kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml >/dev/null 2>&1

echo "[TASK 4] Generate and save cluster join command"
kubeadm token create --print-join-command > /joincluster.sh 2>/dev/null
cp /joincluster.sh /vagrant/joincluster.sh
