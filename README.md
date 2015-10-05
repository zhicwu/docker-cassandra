# docker-cassandra
Apache Cassandra docker image for development and testing purposes.

## What's inside
```
ubuntu:14.04
 |
 |--- zhicwu/java:7
       |
       |--- zhicwu/cassandra:2.1.9
```
* Official Ubuntu Trusty(14.04) docker image
* Oracle JDK 7 latest release
* [Apache Cassandra](http://cassandra.apache.org/) 2.1.x stable release
* [Stratio's Cassandra Lucene Index](https://github.com/Stratio/cassandra-lucene-index)
* [Jolokia](https://jolokia.org/) as the JMX-HTTP bridge

## How to use
- Pull the image
```
# docker pull zhicwu/cassandra:2.1.9
```
- Setup scripts
```
# wget https://raw.githubusercontent.com/zhicwu/docker-cassandra/master/cluster-env.sh
# wget https://raw.githubusercontent.com/zhicwu/docker-cassandra/master/node-env.sh
# wget https://raw.githubusercontent.com/zhicwu/docker-cassandra/master/start_node.sh
# chmod +x *.sh
```
- Start Cassandra
```
# ./start_node.sh
# docker logs -f my-cassandra
...
# docker exec -it my-cassandra bash
$ cqlsh -u cassandra -p cassandra
```
You can now use cassandra/cassandra to access the node.

Tips:

1. Edit _cluster-env.sh_ to customize cluster environment, which should be same for all nodes in a certain data center
2. Edit _node-env.sh_ to customize node environment
3. Edit _start_node.sh_ to customize docker start options
3. To enable Jolokia, make changes in _node-env.sh_ like the following, restart Cassandra and connect using tools like  [hawtio](http://hawt.io/)
```
JMX_REMOTE="yes"
JOLOKIA_ENABLED="yes"
JMX_USERNAME="ffa"
JMX_PASSWORD="ffa"
```
