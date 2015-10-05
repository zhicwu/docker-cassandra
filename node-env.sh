#!/bin/bash
#IP=`ifconfig | sed -En 's/127.0.0.//;s/172.17.42.//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`
IP="127.0.0.1"
DC="DC1"
RACK="RACK1"

DATA_DIR="/data/cassandra"