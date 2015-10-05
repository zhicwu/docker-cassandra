#!/usr/bin/env bash

cdir="`dirname "$0"`"
cdir="`cd "$cdir"; pwd`"

echo "* Load cluster environment variables from $cdir/cluster-env.sh..."
. "$cdir/cluster-env.sh"

echo "* Load node-specific environment variables from $cddir/node-env.sh..."
. "$cdir/node-env.sh"

if [ "$CLUSTER" = "" ]; then
  CLUSTER="My C* Cluster"
fi

if [ "$SEEDS" = "" ]; then
  SEEDS="127.0.0.1"
fi

if [ "$IP" = "" ]; then
  IP=`ifconfig | sed -En 's/127.0.0.//;s/172.17.42.//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`
fi

if [ "$DC" = "" ]; then
  DC="DC1"
fi

if [ "$RACK" = "" ]; then
  RACK="RACK1"
fi

if [ "$DATA_DIR" = "" ]; then
  DATA_DIR="/data"
fi

echo "* Loaded environment variables:"
echo "* - CLUSTER   = $CLUSTER"
echo "* - SEEDS     = $SEEDS"
echo "* - IP        = $IP"
echo "* - DC        = $DC"
echo "* - RACK      = $RACK"

if [ -d $DATA_DIR ]; then
  echo "* Reuse existing data directory: $DATA_DIR"
else
  echo "* Create data directory: $DATA_DIR"
  mkdir -p $DATA_DIR
fi

mkdir -p $DATA_DIR/data
mkdir -p $DATA_DIR/commitlog
mkdir -p $DATA_DIR/saved_caches
# use the hard-coded user and group IDs
chown -R 7878:7878 $DATA_DIR

# use --privileged=true has the potential risk of causing clock drift
# references: http://stackoverflow.com/questions/24288616/permission-denied-on-accessing-host-directory-in-docker
docker run -d --name my-cassandra --net=host --memory-swap=-1 --user=cassandra \
	--ulimit nofile=100000 --ulimit nproc=8096 --ulimit memlock=17179869184 \
	-e JMX_USERNAME="$JMX_USERNAME" -e JMX_PASSWORD="$JMX_PASSWORD" \
	-e CASSANDRA_CLUSTER_NAME="$CLUSTER" -e CASSANDRA_DC="$DC" -e CASSANDRA_RACK="$RACK" \
	-e CASSANDRA_BROADCAST_ADDRESS="$IP" -e CASSANDRA_SEEDS="$SEEDS" \
	-e CASSANDRA_ENDPOINT_SNITCH="GossipingPropertyFileSnitch" \
	-v $DATA_DIR:/var/lib/cassandra:Z zhicwu/cassandra:2.1.9
