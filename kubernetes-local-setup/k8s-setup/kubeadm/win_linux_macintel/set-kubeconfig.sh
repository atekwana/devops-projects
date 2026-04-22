#!/bin/bash

set -e

USER=vagrant
HOME_DIR=/home/$USER
KUBE_CONFIG_SRC=/etc/kubernetes/admin.conf

mkdir -p "$HOME_DIR/.kube"
mkdir -p /root/.kube

if [ -f "$KUBE_CONFIG_SRC" ]; then

  # set up for root user
  cp -f "$KUBE_CONFIG_SRC" /root/.kube/config
  chmod 644 /root/.kube/config
  echo "KUBECONFIG INSTALLED SUCCESSFULLY FOR ROOT USER"

  # set up for vagrant user
  cp -f "$KUBE_CONFIG_SRC" "$HOME_DIR/.kube/config"
  chown $USER:$USER "$HOME_DIR/.kube"
  chmod 644 "$HOME_DIR/.kube/config"
  echo "KUBECONFIG INSTALLED SUCCESSFULLY FOR VAGRANT USER"

else
  echo "ERROR --- $KUBE_CONFIG_SRC NOT FOUND! — KUBEINIT FAILED!"
  exit 1
fi
