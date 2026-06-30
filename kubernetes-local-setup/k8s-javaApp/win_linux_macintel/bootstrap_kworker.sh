#!/bin/bash
## Worker node initialization script
## Runs after bootstrap.sh completes on kworker1 and kworker2

echo "[TASK 1] Join node to Kubernetes Cluster"
# Copy the join command from the shared Vagrant folder (no SSH/password needed)
cp /vagrant/joincluster.sh /joincluster.sh

echo "[TASK 2] Execute join command"
bash /joincluster.sh
#!/bin/bash
## Worker node initialization script
## Runs after bootstrap.sh completes on kworker1 and kworker2

echo "[TASK 1] Wait for kmaster API server to be ready"
until curl -k -s --max-time 2 https://192.168.33.2:6443 >/dev/null; do
  sleep 5
done

echo "[TASK 2] Join node to Kubernetes Cluster"
cp /vagrant/joincluster.sh /joincluster.sh

echo "[TASK 3] Execute join command"
bash /joincluster.sh
