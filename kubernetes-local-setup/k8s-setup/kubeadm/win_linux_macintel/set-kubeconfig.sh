#!/bin/bash

set -e

USER=vagrant
HOME_DIR=/home/$USER
KUBE_CONFIG_SRC=/etc/kubernetes/admin.conf
KUBE_CONFIG_DST=$HOME_DIR/.kube/config

mkdir -p "$HOME_DIR/.kube"

if [ -f "$KUBE_CONFIG_SRC" ]; then

  # set up for root user
  mkdir -p /.kube/config
  cp -f "$KUBE_CONFIG_SRC" /root/.kube/config
  chmod 644 /root/.kube/config
  echo "KUBECONFIG INSTALLED SUCCESSFULLY FOR ROOT USER"

  # set up for vagrant user
  cp -f "$KUBE_CONFIG_SRC" "$KUBE_CONFIG_DST"
  chown $USER:$USER "$HOME_DIR/.kube"
  chmod 644 "$KUBE_CONFIG_DST"
  echo "KUBECONFIG INSTALLED SUCCESSFULLY FOR VAGRANT USER"

else
  echo "ERROR --- $KUBE_CONFIG_SRC NOT FOUND! — KUBEINIT FAILED!"
  exit 1
fi
