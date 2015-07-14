#!/usr/bin/env bash

# Setup
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)

# Add the repository
echo "deb http://repos.mesosphere.io/${DISTRO} ${CODENAME} main" | \
  sudo tee /etc/apt/sources.list.d/mesosphere.list
sudo apt-get -y update

function join { local IFS="$1"; shift; echo "$*"; }

function mesos-cluster {
  local ZKS=()
  for IP in "${IPS[@]}"
  do
    ZKS+=("${IP}:2181")
  done
  echo "zk://$(join , "${ZKS[@]}")/mesos" #> /etc/mesos/zk
}
