#!/bin/bash

#installing epel-release repo for extra packages
#update the system
sudo yum install epel-release -y
sudo yum update -y

#wget is a utility for downloading files from the web
sudo yum install wget -y

#in tmp dir, install centOS repo that provides rabbitMQ packages
cd /tmp/
dnf -y install centos-release-rabbitmq-38

#install rabbitMQ server from repo
#enable & start rabbitMQ server
 dnf --enablerepo=centos-rabbitmq-38 -y install rabbitmq-server
 systemctl enable --now rabbitmq-server//

 #open port 5672 for rabbitMQ default port for client connections
 #make firewall rule permanent
 firewall-cmd --add-port=5672/tcp
 firewall-cmd --runtime-to-permanent

#start & restart systemctl
sudo systemctl start rabbitmq-server
sudo systemctl enable rabbitmq-server
sudo systemctl status rabbitmq-server

#let rabbirMQ to allow connections from users
sudo sh -c 'echo "[{rabbit, [{loopback_users, []}]}]." > /etc/rabbitmq/rabbitmq.config'

#add and configure rabbitMQ user
sudo rabbitmqctl add_user test test
sudo rabbitmqctl set_user_tags test administrator
sudo systemctl restart rabbitmq-server
