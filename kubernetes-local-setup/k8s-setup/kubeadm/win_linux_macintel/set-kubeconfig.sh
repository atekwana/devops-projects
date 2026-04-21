#!/bin/bash

set -e

USER=vagrant
HOME_DIR=/home/$USER
KUBE_CONFIG_SRC=/etc/kubernetes/admin.conf
KUBE_CONFIG_DST=$HOME_DIR/.kube/config

mkdir -p "$HOME_DIR/.kube"

if [ -f "$KUBE_CONFIG_SRC" ]; then
  cp -f "$KUBE_CONFIG_SRC" "$KUBE_CONFIG_DST"
  chown $USER:$USER "$HOME_DIR/.kube"
  echo "kubeconfig installed successfully"
else
  echo "ERROR: $KUBE_CONFIG_SRC not found — kubeadm init may have failed"
  exit 1
fi
