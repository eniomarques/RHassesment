#!/usr/bin/bash
# 04/10/2021 v1.0 - eniomarques@gmail.com - Script to deploy Strimzi to K8S


STRIMZIOPNS=$1
#STRIMZIOPNS=kafka
KAFKACLUSTERNS=$2
#KAFKACLUSTERNS=my-kafka-project


if [ "$#" -ne 2 ]; then
  echo "Usage example: $0 kafka my-kafka-project" >&2
  exit 1
fi



INSTALLDIR=/opt/strimzi/strimzi-0.22.1/install
STRIMZIOPYAML=$INSTALLDIR/cluster-operator/060-Deployment-strimzi-cluster-operator.yaml


if [ ! -d /opt/strimzi ]; then
  mkdir -p /opt/strimzi
fi

#if using the same ns for both Strimzi and Kafka cluster
if [[ -z $KAFKACLUSTERNS ]]; then
  KAFKACLUSTERNS=$STRIMZIOPNS
fi



#Downloading and extracting Strimzi
wget https://github.com/strimzi/strimzi-kafka-operator/releases/download/0.22.1/strimzi-0.22.1.zip -P /tmp/

unzip /tmp/strimzi-0.22.1.zip -d /opt/strimzi
rm /tmp/strimzi-0.22.1.zip


# Creating the namespace for the Strimzi Kafka Cluster Operator and preparing the yaml files with correct namespace
kubectl create ns $STRIMZIOPNS

sed -i "s/namespace: .*/namespace: $STRIMZIOPNS/" $INSTALLDIR/cluster-operator/*RoleBinding*.yaml


# Creating the NS for Kafka cluster deploy, only if different from the other ns

if [ "$STRIMZIOPNS" != "$KAFKACLUSTERNS" ]; then
kubectl create ns $KAFKACLUSTERNS
fi


# Set the correct STRIMZI_NAMESPACE env variable in the yaml file
sed -i --e '/STRIMZI_NAMESPACE/,+3d' $STRIMZIOPYAML
sed -i "/env:/a \            - name: STRIMZI_NAMESPACE\n              value: $KAFKACLUSTERNS" $STRIMZIOPYAML


# Deploy CRD, RBAC and permissions
kubectl create -f $INSTALLDIR/cluster-operator/ -n $STRIMZIOPNS

kubectl create -f $INSTALLDIR/cluster-operator/020-RoleBinding-strimzi-cluster-operator.yaml -n $KAFKACLUSTERNS

kubectl create -f $INSTALLDIR/cluster-operator/032-RoleBinding-strimzi-cluster-operator-topic-operator-delegation.yaml -n $KAFKACLUSTERNS

kubectl create -f $INSTALLDIR/cluster-operator/031-RoleBinding-strimzi-cluster-operator-entity-operator-delegation.yaml -n $KAFKACLUSTERNS



#Create a new Kafka cluster with one ZooKeeper and one Kafka broker.
kubectl create -n $KAFKACLUSTERNS -f $(dirname "$0")/kafkaCluster.yaml

echo -e "\nWaiting for the Kafka cluster to be ready..."
kubectl wait $STRIMZIOPNS/my-cluster --for=condition=Ready --timeout=300s -n $KAFKACLUSTERNS

#Create the topic after cluster is available
#kubectl create -n $KAFKACLUSTERNS -f $(dirname "$0")/kafkaTopic.yaml


echo -e "\nDisplaying Kafka IP and Port for non container connection:"
# Display Node IP for connection
kubectl get nodes --output=jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'

# Display Kafka Port for connection
kubectl get service my-cluster-kafka-external-bootstrap -n $KAFKACLUSTERNS -o=jsonpath='{.spec.ports[0].nodePort}{"\n"}'


echo -e "\nCreating and deploying the example stream app - reverse strings in the 'client' NS..."
# Creating the new NS for the client example (3rd point in the intvw doc)
kubectl create ns client

# deploying the producer, consumer and streams - used the simplest method to cross ns, by adding the other ns name in the bootstrap address
kubectl create -f $(dirname "$0")/clientexample.yaml -n client



sleep 3
echo -e "\nCreating the NS for base64 streams and deployment, in the 'base64streams' NS..."

# Creating the NS for modified streams - base64 encoder
kubectl create ns base64streams

# Deploying the base64 encoder example, it uses different topics from the previous kafka cluster, with the same images for consumer and producer, but with my image for streams.
kubectl create -f $(dirname "$0")/base64streams.yaml -n base64streams
