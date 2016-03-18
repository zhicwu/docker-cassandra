#!/bin/bash
# IP=`ifconfig | sed -En 's/127.0.0.//;s/172.17.42.//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`
IP="127.0.0.1"
DC="MyDC"
RACK="MyRACK"
# DATA_DIR="/data/cassandra"
#NUM_TOKENS=1
# python -c 'print [str(((2**64 / number_of_tokens) * i) - 2**63) for i in range(number_of_tokens)]'
#INITIAL_TOKEN=0