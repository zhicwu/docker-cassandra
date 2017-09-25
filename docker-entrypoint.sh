#!/bin/bash
set -e

# first arg is `-f` or `--some-option`
if [ "${1:0:1}" = '-' ]; then
	set -- cassandra -f "$@"
fi

if [ "$1" = 'cassandra' ]; then
	chown -R cassandra:cassandra /var/lib/cassandra

	if [ "$JMX_USERNAME" = '' ]; then
		JMX_USERNAME="ffa"
	fi

	if [ "$JMX_PASSWORD" = '' ]; then
		JMX_PASSWORD="ffa"
	fi

	# Generate jmx password file
	cp -f $JAVA_HOME/jre/lib/management/jmxremote.access.bak $JAVA_HOME/jre/lib/management/jmxremote.access
	rm -f $CASSANDRA_CONF/jmxremote.password

	if [ "$JMX_REMOTE" = 'yes' ]; then
		sed -ri 's:(LOCAL_JMX=).*:\1no:' "$CASSANDRA_CONF/cassandra-env.sh"

		echo "$JMX_USERNAME   readwrite" >> $JAVA_HOME/jre/lib/management/jmxremote.access

		echo "# This file will be re-generated each time (re)starting the container" > $CASSANDRA_CONF/jmxremote.password
		echo 'monitorRole '`cat /dev/urandom|tr -dc "a-zA-Z0-9-_\$\?"|fold -w 15|head -15 | tail -1` >> $CASSANDRA_CONF/jmxremote.password
		echo 'controlRole '`cat /dev/urandom|tr -dc "a-zA-Z0-9-_\$\?"|fold -w 15|head -15 | tail -1` >> $CASSANDRA_CONF/jmxremote.password
		echo "$JMX_USERNAME $JMX_PASSWORD" >> $CASSANDRA_CONF/jmxremote.password
		chown cassandra:cassandra $CASSANDRA_CONF/jmxremote.password
		chmod 400 $CASSANDRA_CONF/jmxremote.password

		# Update JMX agent configuration
		if [ "$JOLOKIA_ENABLED" = 'yes' ]; then
			sed -ri 's:(JVM_OPTS=\"\$JVM_OPTS).*(\$JVM_EXTRA_OPTS)\":\1 -javaagent\:'`echo ${CASSANDRA_LIB}/jolokia-jvm-${JOLOKIA_VERSION}-agent.jar=host=${JOLOKIA_HOST},port=${JOLOKIA_PORT},user=${JMX_USERNAME},password=${JMX_PASSWORD}`' \2":' "$CASSANDRA_CONF/cassandra-env.sh"
		fi
	else
		sed -ri 's:(LOCAL_JMX=).*:\1yes:' "$CASSANDRA_CONF/cassandra-env.sh"
	fi

	# TODO detect if this is a restart if necessary
	: ${CASSANDRA_LISTEN_ADDRESS='auto'}
	if [ "$CASSANDRA_LISTEN_ADDRESS" = 'auto' ]; then
		CASSANDRA_LISTEN_ADDRESS="$(hostname --ip-address)"
	fi

	: ${CASSANDRA_BROADCAST_ADDRESS="$CASSANDRA_LISTEN_ADDRESS"}

	if [ "$CASSANDRA_BROADCAST_ADDRESS" = 'auto' ]; then
		CASSANDRA_BROADCAST_ADDRESS="$(hostname --ip-address)"
	fi
	: ${CASSANDRA_BROADCAST_RPC_ADDRESS:=$CASSANDRA_BROADCAST_ADDRESS}

	: ${CASSANDRA_SEEDS:="$CASSANDRA_BROADCAST_ADDRESS"}
	
	sed -ri 's/(- seeds:) "127.0.0.1"/\1 "'"$CASSANDRA_SEEDS"'"/' "$CASSANDRA_CONF/cassandra.yaml"

	# turn on authentication and authorization by default
	sed -ri 's/(authenticator:) AllowAllAuthenticator/\1 PasswordAuthenticator/' "$CASSANDRA_CONF/cassandra.yaml" 
	sed -ri 's/(authorizer:) AllowAllAuthorizer/\1 CassandraAuthorizer/' "$CASSANDRA_CONF/cassandra.yaml"

	for yaml in \
		broadcast_address \
		broadcast_rpc_address \
		cluster_name \
		endpoint_snitch \
		listen_address \
		num_tokens \
		initial_token \
	; do
		var="CASSANDRA_${yaml^^}"
		val="${!var}"
		if [ "$val" ]; then
			sed -ri 's/^(# )?('"$yaml"':).*/\2 '"$val"'/' "$CASSANDRA_CONF/cassandra.yaml"
		fi
	done

	for rackdc in dc rack; do
		var="CASSANDRA_${rackdc^^}"
		val="${!var}"
		if [ "$val" ]; then
			sed -ri 's/^('"$rackdc"'=).*/\1 '"$val"'/' "$CASSANDRA_CONF/cassandra-rackdc.properties"
		fi
	done
fi

exec "$@"
