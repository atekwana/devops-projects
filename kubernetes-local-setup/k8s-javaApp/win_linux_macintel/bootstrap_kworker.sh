#!/bin/bash
## Worker node initialization script
## Runs after bootstrap.sh completes on kworker1 and kworker2

echo "[TASK 1] Join node to Kubernetes Cluster"
# Copy the join command from the shared Vagrant folder (no SSH/password needed)
cp /vagrant/joincluster.sh /joincluster.sh

echo "[TASK 2] Execute join command"
bash /joincluster.sh
