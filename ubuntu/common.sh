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

sudo apt-get install -y curl

# Setup
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)

# Add the repository
echo "deb http://repos.mesosphere.io/${DISTRO} ${CODENAME} main" | \
  sudo tee /etc/apt/sources.list.d/mesosphere.list
sudo apt-get -y update

function join { local IFS="$1"; shift; echo "$*"; }

function fore { local str=$(printf "%q" "$1"); shift; eval echo "\"\${@/#/${str}}\""; }

function aft { local str=$(printf "%q" "$1"); shift; eval echo "\"\${@/%/${str}}\""; }

function surround { local str=$1; shift; echo $(fore $str $(aft $str "$@")); }

function filter { local pattern=$1; shift; eval echo "\"\${@//${pattern}/}\""; }

function mesos-cluster {
  echo "zk://$(join , $(aft :2181 "${IPS[@]}"))/mesos" > /etc/mesos/zk
}
