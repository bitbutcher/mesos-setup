#!/usr/bin/env bash

if [ -z "${CONSUL_VERSION}" ] ; then
  echo "CONSUL_VERSION env var must be set. Aborting consul install." >&2; exit 1
fi
if [ -z "${DATACENTER}" ] ; then
  echo "DATACENTER env var must be set. Aborting consul install." >&2; exit 1
fi

JOIN_CLUSTER=$(join , $(surround \" $(filter $NODE_IP "${IPS[@]}")))
if [ "$NODE_IP" -eq "${IPS[0]}"]; then
  CONSUL_ROLE="bootstrap"
else
  if [ -z "${CONSUL_KEY}" ] ; then
    echo "CONSUL_KEY env var must be set for non-bootstrap role. Aborting consul install." >&2; exit 1
  fi
  if [ ${#IPS[@]} -eq ${#JOIN_CLUSTER[@]} ]; then
    CONSUL_ROLE="client"
  else
    CONSUL_ROLE="server"
  fi
fi

sudo apt-get install -y unzip

# create the consul user
sudo adduser consul

# install the base consul binaries
curl -0L "https://dl.bintray.com/mitchellh/consul/${CONSUL_VERSION}_linux_amd64.zip"
unzip "${CONSUL_VERSION}_linux_amd64.zip"
sudo mv consul /usr/local/bin/consul
rm "${CONSUL_VERSION}_linux_amd64.zip"

# setup configurations for all agent roles
if [ "${CONSUL_ROLE}" -eq "bootstrap" ]; then
  CONSUL_KEY=$(consul keygen)
  echo "!!! SAVE THIS KEY >>> ${CONSUL_KEY} <<< SAVE THIS KEY !!!"
fi

for ROLE in "bootrap server client"
do
  local CONF_DIR="/etc/consul.d/${ROLE}"
  sudo mkdir -p $DIR
  cp "${SCRIPT_DIR}/consul/${ROLE}.json" "${CONF_DIR}/config.json"
  sed -e "s/{{datacenter}}/${DATACENTER}/" -e "s/{{key}}/${CONSUL_KEY}/" -e "s/{{cluster}}/${JOIN_CLUSTER}/" "${CONF_DIR}/config.json"
done

# setup the data directory
sudo mkdir -p /var/lib/consul
sudo chown -R consul:consul /var/lib/consul

# create the upstart service
cp "${SCRIPT_DIR}/consul/init.conf" "/etc/init/consul.conf"

if [ "${CONSUL_ROLE}" -eq "client" ]; then
  # install the web ui on the slave
  curl -0L "https://dl.bintray.com/mitchellh/consul/${CONSUL_VERSION}_web_ui.zip"
  unzip "${CONSUL_VERSION}_web_ui.zip"
  sudo mkdir -p /usr/share/consul
  sudo mv dist /usr/share/consul/ui
  sudo chown -R consul:consul /usr/share/consul
  rm "${CONSUL_VERSION}_web_ui.zip"

  # set the role of the upstart service to 'client'
  sed -e "s/{{role}}/client" "/etc/init/consul.conf"
else
  # set the role of the upstart service to server
  sed -e "s/{{role}}/server" "/etc/init/consul.conf"
fi

# conditionally bootstrap the consul cluster
if [ "${CONSUL_ROLE}" -eq "bootstrap" ]; then
  # bootstrap the consul cluster
  su consul
  timout 5 consul agent -config-dir /etc/consul.d/bootstrap
fi

# start up the consul service
start consul
