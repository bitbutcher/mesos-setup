#!/usr/bin/env bash

NODE_IP=$1
shift
IPS=( "$@" )

source ./common.sh

# install mesos
sudo apt-get -y install mesos

# take this node out of the master pool
sudo service zookeeper stop
sudo sh -c "echo manual > /etc/init/zookeeper.override"
sudo service mesos-master stop
sudo sh -c "echo manual > /etc/init/mesos-master.override"

# configure mesos master cluster
mesos-cluster

# configure hostnames as ip addresses for VPN access to web consoles
echo $NODE_IP > /etc/mesos-slave/hostname
echo $NODE_IP > /etc/marathon/conf/hostname

# restart the mesos slave service
sudo service mesos-slave restart
