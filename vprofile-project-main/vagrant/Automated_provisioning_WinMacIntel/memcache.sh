#!/bin/bash

# installing epel repository & memcached
# epel-release is a repo that provides additional packages
sudo dnf install epel-release -y
sudo dnf install memcached -y

#start and enable memcached
sudo systemctl start memcached
sudo systemctl enable memcached
sudo systemctl status memcached

#configure memcached to listen on all networks interfaces
#modify the configuration to change the listening our ip address
sed -i 's/127.0.0.1/0.0.0.0/g' /etc/sysconfig/memcached
sudo systemctl restart memcached

#configure firewall
#open port 11211 for tcp traffic
#make firewall rule permanent
#open port 11111 for UDP traffic
firewall-cmd --add-port=11211/tcp
firewall-cmd --runtime-to-permanent
firewall-cmd --add-port=11111/udp
firewall-cmd --runtime-to-permanent
sudo memcached -p 11211 -U 11111 -u memcached -d
