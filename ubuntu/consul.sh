#!/usr/bin/env bash

sudo apt-get install -y curl unzip

# create the consul user
sudo adduser consul

# install the base consul binaries
curl -0L "https://dl.bintray.com/mitchellh/consul/${CONSUL_VER}_linux_amd64.zip"
unzip "${CONSUL_VER}_linux_amd64.zip"
sudo mv consul /usr/local/bin/consul
rm "${CONSUL_VER}_linux_amd64.zip"

# setup configurations for all agent roles
JOIN_CLUSTER=$(join , $(surround \" $(filter $NODE_IP "${IPS[@]}")))
for ROLE in "bootrap server client"
do
  local CONF_DIR="/etc/consul.d/${ROLE}"
  sudo mkdir -p $DIR
  cp "${SCRIPT_DIR}/consul/${ROLE}.json" "${CONF_DIR}/config.json"
  sed -e "s/{{datacenter}}/${DATACENTER}/" -e "s/{{key}}/${ENCRYPT_KEY}/" -e "s/{{cluster}}/${JOIN_CLUSTER}/" "${CONF_DIR}/config.json"
done

# setup the data directory
sudo mkdir -p /var/lib/consul
sudo chown -R consul:consul /var/lib/consul

# create the upstart service
cp "${SCRIPT_DIR}/consul/init.conf" "/etc/init/consul.conf"

if [ ${#IPS[@]} -eq ${#JOIN_CLUSTER[@]} ]; then
  # install the web ui on the slave
  curl -0L "https://dl.bintray.com/mitchellh/consul/${CONSUL_VER}_web_ui.zip"
  unzip "${CONSUL_VER}_web_ui.zip"
  sudo mkdir -p /usr/share/consul
  sudo mv dist /usr/share/consul/ui
  sudo chown -R consul:consul /usr/share/consul
  rm "${CONSUL_VER}_web_ui.zip"

  # set the role of the upstart service to 'client'
  sed -e "s/{{role}}/client" "/etc/init/consul.conf"
else
  # set the role of the upstart service to server
  sed -e "s/{{role}}/server" "/etc/init/consul.conf"
fi

# conditionally bootsrap the consul cluster
if [ "$NODE_IP" -eq "${IPS[0]}"]; then
  # bootstrap the consul cluster
  su consul
  timout 5 consul agent -config-dir /etc/consul.d/bootstrap
fi

# start up the consul service
start consul
