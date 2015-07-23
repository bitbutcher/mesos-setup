#!/usr/bin/env bash

if [ "$NODE_IP" != "${IPS[0]}" ]; then
  echo "exiting since this node is not the kubernetes master"
  exit 0
fi
if [ -z "${KUBERNETES_VERSION}" ]; then
  echo "KUBERNETES_VERSION env var must be set. Aborting kubernetes install." >&2; exit 1
fi

STAGING_DIR=$(mktemp -dt "$(basename $0).XXXXXXXXX")
pushd "${STAGING_DIR}"

# add kubernetes dependencies: make, go, docker
sudo apt-get install make

# install go
GO_FILE_NAME="go1.4.2.linux-amd64.tar.gz"
curl -OL "https://storage.googleapis.com/golang/${GO_FILE_NAME}"
tar -C /usr/local -xzf "${GO_FILE_NAME}"
GO_PATH_SETUP="/etc/profile.d/golang.sh"
echo 'export PATH="/usr/local/go/bin:${PATH}"' > "${GO_PATH_SETUP}"
source "${GO_PATH_SETUP}"

curl -sSL https://get.docker.com/ | sh

# build kubernetes
git clone https://github.com/GoogleCloudPlatform/kubernetes
git checkout "tags/v${KUBERNETES_VERSION}"
pushd kubernetes
  KUBERNETES_CONTRIB=mesos make
  mv "_output/local/go/bin/*" "/usr/local/go/bin"
popd

MESOS_MASTER=$(cat /etc/mesos/zk)
KUBERNETES_MASTER_IP="${NODE_IP}"
KUBERNETES_MASTER="http://${KUBERNETES_MASTER_IP}:8888"

# start etcd
sudo docker run -d --hostname $(uname -n) --name etcd \
-p 4001:4001 -p 7001:7001 quay.io/coreos/etcd:v2.0.12 \
--listen-client-urls http://0.0.0.0:4001 \
--advertise-client-urls http://${KUBERNETES_MASTER_IP}:4001


# create a cloug config file
cat <<EOF >mesos-cloud.conf
[mesos-cloud]
mesos-master = ${MESOS_MASTER}
EOF

# Now start the kubernetes-mesos API server, controller manager, and scheduler
km apiserver \
  --address=${KUBERNETES_MASTER_IP} \
  --etcd-servers=http://${KUBERNETES_MASTER_IP}:4001 \
  --service-cluster-ip-range=10.10.10.0/24 \
  --port=8888 \
  --cloud-provider=mesos \
  --cloud-config=mesos-cloud.conf \
  --v=1 >apiserver.log 2>&1 &

km controller-manager \
  --master=${KUBERNETES_MASTER_IP}:8888 \
  --cloud-provider=mesos \
  --cloud-config=./mesos-cloud.conf  \
  --v=1 >controller.log 2>&1 &

km scheduler \
  --address=${KUBERNETES_MASTER_IP} \
  --mesos-master=${MESOS_MASTER} \
  --etcd-servers=http://${KUBERNETES_MASTER_IP}:4001 \
  --mesos-user=root \
  --api-servers=${KUBERNETES_MASTER_IP}:8888 \
  --cluster-dns=10.10.10.10 \
  --cluster-domain=cluster.local \
  --v=2 >scheduler.log 2>&1 &

  disown -a

popd
rm -rf "${STAGING_DIR}"
