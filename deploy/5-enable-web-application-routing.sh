#!/bin/bash

# https://learn.microsoft.com/en-us/azure/aks/app-routing?tabs=default%2Cdeploy-app-default

# Enable on an exising cluster

AKS_CLUSTER_NAME="aks-1-pp-acio-eastus2"
RESOURCE_GROUP_NAME="rg-${AKS_CLUSTER_NAME}"

az aks approuting enable -g ${RESOURCE_GROUP_NAME} -n ${AKS_CLUSTER_NAME}