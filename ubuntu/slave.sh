#!/usr/bin/env bash

USAGE="slave.sh <node_ip> <master_ip> [master_ip...]"

if ! [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] ; then
   echo $USAGE >&2; exit 1
fi

NODE_IP=$1
shift
IPS=( "$@" )

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/common.sh"

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
mkdir -p /etc/marathon/conf
echo $NODE_IP > /etc/marathon/conf/hostname

# restart the mesos slave service
sudo service mesos-slave restart
