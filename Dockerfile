#
# This docker image is just for development and testing purpose - please do NOT use on production
#

# Pull Base Image
FROM zhicwu/java:8

# Set Maintainer Details
MAINTAINER Zhichun Wu <zhicwu@gmail.com>

# Set Environment Variables
ENV CASSANDRA_VERSION=3.0.5 CASSANDRA_LUCENE_INDEX_VERSION=3.0.5
ENV CASSANDRA_CONF=/etc/cassandra CASSANDRA_LIB=/usr/share/cassandra/lib CASSANDRA_DATA=/var/lib/cassandra CASSANDRA_LOG=/var/log/cassandra

#ENV MX4J_VERSION=3.0.1 MX4J_ADDRESS=0.0.0.0 MX4J_PORT=18081
ENV JOLOKIA_VERSION=1.3.3 JOLOKIA_HOST=0.0.0.0 JOLOKIA_PORT=8778

# Set Labels - mx4j_version="MX4J Tools $MX4J_VESION"
LABEL cassandra_version="Apache Cassandra $CASSANDRA_VERSION" jolokia_version="Jolokia ${JOLOKIA_VERSION}"

# Create Hard-coded Cassandra User and Group
RUN groupadd -g 7878 cassandra \
	&& useradd -u 7878 -g cassandra -s /bin/sh -d $CASSANDRA_LIB cassandra

# Install Cassandra - copied from https://github.com/docker-library/cassandra/blob/c7d43443c2e80ee9edd0814c8e8332781f7d93ae/2.1/Dockerfile
RUN apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 514A2AD631A57A16DD0047EC749D6EEC0353B12C
RUN echo 'deb http://www.apache.org/dist/cassandra/debian '`echo "${CASSANDRA_VERSION}" | awk '{split($0,v,"."); print v[1] v[2]}'`'x main' \
	>> /etc/apt/sources.list.d/cassandra.list
RUN apt-get update && apt-get install -y cassandra="$CASSANDRA_VERSION"

RUN sed -ri ' \
		s/^(rpc_address:).*/\1 0.0.0.0/; \
	' "$CASSANDRA_CONF/cassandra.yaml" \
	&& chown -R cassandra:cassandra $CASSANDRA_CONF $CASSANDRA_DATA $CASSANDRA_LIB $CASSANDRA_LOG

# Add Lucene Index Support
RUN apt-get install -y maven \
	&& wget https://github.com/Stratio/cassandra-lucene-index/archive/branch-${CASSANDRA_LUCENE_INDEX_VERSION}.zip \
	&& unzip branch-${CASSANDRA_LUCENE_INDEX_VERSION}.zip \
	&& cd cassandra-lucene-index* \
	&& mvn clean package \
	&& cd - \
	&& rm -f cassandra-lucene-index*/plugin/target/*-javadoc.jar \
	&& rm -f cassandra-lucene-index*/plugin/target/*-sources.jar \
	&& cp -f cassandra-lucene-index*/plugin/target/cassandra-lucene-index-plugin-*.jar $CASSANDRA_LIB/. \
	&& sed -ri 's:(</configuration>).*:  <logger name="com.stratio" level="INFO"/>\n\1:' "$CASSANDRA_CONF/logback.xml"
# there was a logback.xml file in the jar but seems no longer exists now
#RUN zip -d $CASSANDRA_LIB/cassandra-lucene-index-plugin-*.jar logback.xml || echo "* logback.xml not found in the generated assembly, which is good"
RUN rm -rf branch-${CASSANDRA_LUCENE_INDEX_VERSION}.zip && rm -rf cassandra-lucene-index* && rm -rf ~/.m2
RUN apt-get autoremove --purge -y maven \
	&& rm -rf /var/lib/apt/lists/*

# Setup Remote JMX
RUN cp -f $JAVA_HOME/jre/lib/management/jmxremote.access $JAVA_HOME/jre/lib/management/jmxremote.access.bak \
	&& chown root:cassandra $JAVA_HOME/jre/lib/management/jmxremote.access* \
	&& chmod 664 $JAVA_HOME/jre/lib/management/jmxremote.access*

# Add MX4J
#RUN wget http://central.maven.org/maven2/mx4j/mx4j-tools/${MX4J_VERSION}/mx4j-tools-${MX4J_VERSION}.jar \
#	&& mv mx4j*.jar $CASSANDRA_LIB/. \
#	&& sed -ri 's:#(MX4J_ADDRESS=).*:\1"-Dmx4jaddress='`echo ${MX4J_ADDRESS}`'":' "$CASSANDRA_CONF/cassandra-env.sh" \
#	&& sed -ri 's:#(MX4J_PORT=).*:\1"-Dmx4jport='`echo ${MX4J_PORT}`'":' "$CASSANDRA_CONF/cassandra-env.sh"

# Add Jolokia - please use separate instance hosting hawtio for monitoring / management
RUN wget http://search.maven.org/remotecontent?filepath=org/jolokia/jolokia-jvm/${JOLOKIA_VERSION}/jolokia-jvm-${JOLOKIA_VERSION}-agent.jar \
	-O $CASSANDRA_LIB/jolokia-jvm-${JOLOKIA_VERSION}-agent.jar

VOLUME ["/var/lib/cassandra"]

COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

#  7000: intra-node communication
#  7001: TLS intra-node communication
#  7199: JMX
#  8778: Jolokia
#  9042: CQL
#  9160: thrift service
# 18081: MX4J
EXPOSE 7000 7001 7199 8778 9042 9160

CMD ["cassandra", "-f"]
