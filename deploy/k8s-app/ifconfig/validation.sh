#!/bin/bash

kubectl get ingress -A

EXTERMAL_IP=$(kubectl get ingress ingress-ipconfig-io -n ns-ipconfig --output jsonpath='{.status.loadBalancer.ingress[0].ip}')

curl -H Host:ipconfig.divecode.in $EXTERMAL_IP
