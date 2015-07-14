#!/usr/bin/env bash

# validate master ip list
if [ -z "$1" ] ; then
  echo $USAGE >&2; exit 1
fi
for IP in "$@"
do
  if ! [[ "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] ; then
    echo $USAGE >&2; exit 1
  fi
done

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
