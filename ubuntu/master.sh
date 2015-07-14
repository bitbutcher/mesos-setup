#!/usr/bin/env bash

NODE_ID=$1
shift
IPS=( "$@" )
NODE_IP=${IPS[$NODE_ID - 1]}
SIZE=${#IPS[@]}

source ./common.sh

# install mesos and marathon
sudo apt-get -y install mesos marathon

# configure zookeeper
echo $NODE_ID > /etc/zookeeper/conf/myid
for i in $(seq 1 $SIZE)
do
  echo "server.$i=${IPS[$i - 1]}:2888:3888" >> /etc/zookeeper/conf/zoo.conf
done
sudo service zookeeper restart

# configure mesos master cluster
mesos-cluster

# configure hostnames as ip addresses for VPN access to web consoles
echo $NODE_IP > /etc/mesos-master/hostname
echo $NODE_IP > /etc/marathon/conf/hostname

# set the quorum size based on the number of nodes
echo $(expr $SIZE / 2 + 1) > /etc/mesos-master/quorum

# take this node out of the slave pool
sudo service mesos-slave stop
sudo sh -c "echo manual > /etc/init/mesos-slave.override"

# restart mesos master and marathon
sudo service mesos-master restart
sudo service marathon restart
