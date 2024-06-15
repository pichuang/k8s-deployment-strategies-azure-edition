#!/bin/bash

# AKS_CLUSTER_NAME="aks-2-pp-aci-eastus2"
# RESOURCE_GROUP_NAME="rg-${AKS_CLUSTER_NAME}"

AKS_CLUSTER_NAME="aks-pichuang-japaneast"
RESOURCE_GROUP_NAME="rg-aks-japaneast"

# https://learn.microsoft.com/zh-tw/azure/aks/learn/quick-windows-container-deploy-cli?tabs=add-windows-server-2022-node-pool
az aks nodepool add \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --cluster-name ${AKS_CLUSTER_NAME} \
    --os-type Windows \
    --os-sku Windows2022 \
    --nodepool-name npwins \
    --node-count 1