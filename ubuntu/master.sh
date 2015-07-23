#!/usr/bin/env bash

USAGE="Usage: master.sh <node_id> <master_ip> [master_ip...]"

if ! [[ $1 =~ ^[0-9]+$ ]] ; then
  echo $USAGE >&2; exit 1
fi

NODE_ID=$1
shift
IPS=( "$@" )

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/common.sh"

NODE_IP=${IPS[$NODE_ID - 1]}
SIZE=${#IPS[@]}

# install mesos and marathon
sudo apt-get -y install mesos marathon

# configure zookeeper
echo $NODE_ID > /etc/zookeeper/conf/myid
for i in $(seq 1 $SIZE)
do
  echo "server.$i=${IPS[$i - 1]}:2888:3888" >> /etc/zookeeper/conf/zoo.cfg
done
sudo service zookeeper restart

# configure mesos master cluster
mesos-cluster

# configure hostnames as ip addresses for VPN access to web consoles
echo $NODE_IP > /etc/mesos-master/hostname
mkdir -p /etc/marathon/conf
echo $NODE_IP > /etc/marathon/conf/hostname

# set the quorum size based on the number of nodes
echo $(expr $SIZE / 2 + 1) > /etc/mesos-master/quorum

# take this node out of the slave pool
sudo service mesos-slave stop
sudo sh -c "echo manual > /etc/init/mesos-slave.override"

# restart mesos master and marathon
sudo service mesos-master restart
sudo service marathon restart

# conditionally install consul
source "$SCRIPT_DIR/consul/install.sh"

#conditionally install kubernetes
source "$SCRIPT_DIR/kubernetes/install.sh"
