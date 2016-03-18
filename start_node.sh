#!/bin/bash
CASSANDRA_ALIAS="my-cassandra"
CASSANDRA_TAG="3.0"
CASSANDRA_UID=7878
CASSANDRA_GID=7878

cdir="`dirname "$0"`"
cdir="`cd "$cdir"; pwd`"

[[ "$TRACE" ]] && set -x

_log() {
  [[ "$2" ]] && echo "[`date +'%Y-%m-%d %H:%M:%S.%N'`] - $1 - $2"
}

info() {
  [[ "$1" ]] && _log "INFO" "$1"
}

warn() {
  [[ "$1" ]] && _log "WARN" "$1"
}

setup_env_vars() {
  info "Load cluster environment variables from $cdir/cluster-env.sh..."
  if [ -f $cdir/cluster-env.sh ]
  then
    . "$cdir/cluster-env.sh"
  else
    warn "Skip clust-env.sh as it does not exist"
  fi

  info "Load node-specific environment variables from $cdir/node-env.sh..."
  if [ -f $cdir/node-env.sh ]
  then
    . "$cdir/node-env.sh"
  else
    warn "Skip node-env.sh as it does not exist"
  fi

  # check environment variables and set defaults as required
  : ${CLUSTER:="My C* Cluster"}
  : ${DC:="DC1"}
  : ${RACK:="RACK1"}
  : ${SEEDS:="127.0.0.1"}
  : ${IP:="127.0.0.1"}
  : ${DATA_DIR:="/tmp/cdata"}
  : ${NUM_TOKENS:="256"}
  : ${INITIAL_TOKEN:=""}

  info "Loaded environment variables:"
  info "	CLUSTER  = $CLUSTER"
  info "	SEEDS    = $SEEDS"
  info "	IP       = $IP"
  info "	DC       = $DC"
  info "	RACK     = $RACK"
  info "	DATA_DIR = $DATA_DIR"
  
  info "	NUM_TOKENS    = $NUM_TOKENS"
  info "	INITIAL_TOKEN = $INITIAL_TOKEN"
}

setup_data_dir() {
  if [ -d $DATA_DIR ]; then
    info "Reuse existing data directory: $DATA_DIR"
  else
    info "Initialize data directory: $DATA_DIR"
    mkdir -p $DATA_DIR
  fi

  # initialize data directories
  mkdir -p $DATA_DIR/data
  mkdir -p $DATA_DIR/commitlog
  mkdir -p $DATA_DIR/saved_caches
  # use the hard-coded user and group IDs defined in Dockerfile
  chown -fR $CASSANDRA_UID:$CASSANDRA_GID $DATA_DIR \
    || warn "Failed to change owner of data directory - try sudo if container exited"
}

start_cassandra() {
  info "Stop and remove \"$CASSANDRA_ALIAS\" if it exists and start new one"
  # stop and remove the container if it exists
  docker stop "$CASSANDRA_ALIAS" >/dev/null 2>&1 && docker rm "$CASSANDRA_ALIAS" >/dev/null 2>&1

  # use --privileged=true has the potential risk of causing clock drift
  # references: http://stackoverflow.com/questions/24288616/permission-denied-on-accessing-host-directory-in-docker
  docker run -d --name="$CASSANDRA_ALIAS" --net=host --memory-swap=-1 --user=cassandra \
    --ulimit nofile=100000 --ulimit nproc=8096 --ulimit memlock=17179869184 \
    --restart=on-failure:2 -e JMX_USERNAME="$JMX_USERNAME" -e JMX_PASSWORD="$JMX_PASSWORD" \
    -e CASSANDRA_CLUSTER_NAME="$CLUSTER" -e CASSANDRA_DC="$DC" -e CASSANDRA_RACK="$RACK" \
    -e CASSANDRA_NUM_TOKENS="$NUM_TOKENS" -e CASSANDRA_INITIAL_TOKEN="$INITIAL_TOKEN" \
    -e CASSANDRA_BROADCAST_ADDRESS="$IP" -e CASSANDRA_SEEDS="$SEEDS" \
    -e CASSANDRA_ENDPOINT_SNITCH="GossipingPropertyFileSnitch" \
    -v $DATA_DIR:/var/lib/cassandra:Z zhicwu/cassandra:$CASSANDRA_TAG

  info "Try 'docker logs -f \"$CASSANDRA_ALIAS\"' to see if this works"
}

main() {
  setup_env_vars
  setup_data_dir
  start_cassandra
}

main "$@"