#!/usr/bin/env bash

if [ -z "${CONSUL_VERSION}" ]; then
  echo "CONSUL_VERSION env var must be set. Aborting consul install." >&2; exit 1
fi
if [ -z "${DATACENTER}" ]; then
  echo "DATACENTER env var must be set. Aborting consul install." >&2; exit 1
fi

JOIN_CLUSTER=($(filter $NODE_IP "${IPS[@]}"))
echo "JOIN_CLUSTER: $JOIN_CLUSTER"
if [ "$NODE_IP" == "${IPS[0]}" ]; then
  CONSUL_ROLE="bootstrap"
else
  if [ -z "${CONSUL_KEY}" ]; then
    echo "CONSUL_KEY env var must be set for non-bootstrap role. Aborting consul install." >&2; exit 1
  fi
  if [ ${#IPS[@]} == ${#JOIN_CLUSTER[@]} ]; then
    CONSUL_ROLE="client"
  else
    CONSUL_ROLE="server"
  fi
fi
echo "CONSUL_ROLE: $CONSUL_ROLE"

sudo apt-get install -y unzip

# create the consul user
sudo adduser consul

# install the base consul binaries
CONSUL_BIN_ZIP="${CONSUL_VERSION}_linux_amd64.zip"
curl -OL "https://dl.bintray.com/mitchellh/consul/${CONSUL_BIN_ZIP}"
unzip "${CONSUL_BIN_ZIP}"
sudo mv consul /usr/local/bin/consul
rm "${CONSUL_BIN_ZIP}"

# setup configurations for all agent roles
if [ "${CONSUL_ROLE}" == "bootstrap" ]; then
  CONSUL_KEY=$(consul keygen)
  echo "!!! SAVE THIS KEY >>> ${CONSUL_KEY} <<< SAVE THIS KEY !!!"
fi

JOIN_CLUSTER=$(join , $(surround \" "${JOIN_CLUSTER[@]}"))
declare -a ROLES=("bootstrap" "server" "client")
for ROLE in "${ROLES[@]}"
do
  CONF_DIR="/etc/consul.d/${ROLE}"
  sudo mkdir -p "${CONF_DIR}"
  cp "${SCRIPT_DIR}/consul/${ROLE}.json" "${CONF_DIR}/config.json"
  sed -i -e "s/{{datacenter}}/${DATACENTER}/" -e "s/{{key}}/${CONSUL_KEY}/" -e "s/{{cluster}}/${JOIN_CLUSTER}/g" "${CONF_DIR}/config.json"
done

# setup the data directory
sudo mkdir -p /var/lib/consul
sudo chown -R consul:consul /var/lib/consul

# create the upstart service
cp "${SCRIPT_DIR}/consul/init.conf" "/etc/init/consul.conf"

if [ "${CONSUL_ROLE}" == "client" ]; then
  # install the web ui on the slave
  CONSUL_WEB_ZIP="${CONSUL_VERSION}_web_ui.zip"
  curl -OL "https://dl.bintray.com/mitchellh/consul/${CONSUL_WEB_ZIP}"
  unzip "${CONSUL_WEB_ZIP}"
  sudo mkdir -p /usr/share/consul
  sudo mv dist /usr/share/consul/ui
  sudo chown -R consul:consul /usr/share/consul
  rm "${CONSUL_WEB_ZIP}"

  # set the role of the upstart service to 'client'
  sed -i -e "s/{{role}}/client/" "/etc/init/consul.conf"
else
  # set the role of the upstart service to server
  sed -i -e "s/{{role}}/server/" "/etc/init/consul.conf"
fi

# conditionally bootstrap the consul cluster
if [ "${CONSUL_ROLE}" == "bootstrap" ]; then
  # bootstrap the consul cluster
  sudo su consul <<SUB
  timout 5 consul agent -config-dir /etc/consul.d/bootstrap
  SUB
fi

# start up the consul service
start consul
