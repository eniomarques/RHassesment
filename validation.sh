#!/usr/bin/bash

ENCODED=`kubectl logs -l app=java-kafka-base64-consumer -n base64streams | grep value | awk '{print $7}'`


for value in $ENCODED; do
  DECODED=`echo $value | base64 --decode`
  echo "Encoded: $value  - Decoded: $DECODED"
done
 
