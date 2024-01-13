#!/bin/bash
set -x

echo "2-deploy-public-aks-with-azure-cni.sh"

az config set extension.use_dynamic_install=yes_without_prompt
az extension add --name aks-preview
az extension update --name aks-preview
az provider register --namespace Microsoft.ContainerService

#
# Variables for Azure Kubernetes Service (AKS)
#

# SUBSCRIPTION_ID="xxx-xxx-xxx-xxx"
SUBSCRIPTION_ID=$(az account show | jq -r .id)

AKS_CLUSTER_NAME="aks-2-pp-aci-eastus2"
AKS_NODE_COUNT=2
RESOURCE_GROUP_NAME="rg-${AKS_CLUSTER_NAME}"
LOCATION="EastUS2"
VNET_NAME="vnet-${AKS_CLUSTER_NAME}"
VNET_ADDRESS_PREFIXES="10.67.0.0/24" # Baseline /24
SUBNET_NODE_NAME="subnet-nodepool"
SUBNET_NODE_ADDRESS_PREFIXES="10.67.0.0/26"
SUBNET_POD_NAME="subnet-podpool"
SUBNET_POD_ADDRESS_PREFIXES="10.67.0.128/25"

# az aks get-versions --location ${LOCATION} --output table
KUBERNETES_VERSION="1.27.7"
CNI_PLUGIN="azure"
NETWORK_POLICY="azure"
NETWORK_DATAPLANE="azure"
#NETWORK_PLUGIN_MODE=""
NODE_VM_SIZE="Standard_B4ms"

#
# Variables for Application Gateway Ingress Controller (AGIC)
#
SUBNET_AGIC_NAME="subnet-agic"
SUBNET_AGIC_ADDRESS_PREFIXES="10.67.0.64/26"
AGIC_PRIVATE_IP="10.67.0.68"
AGIC_NAME="agic-${AKS_CLUSTER_NAME}"
AGIC_PUBLIC_IP_NAME="pip-${AGIC_NAME}"

#
# Step 1: Create a resource group
#

az group create --name ${RESOURCE_GROUP_NAME} --location ${LOCATION}

#
# Step 2: Create a VNet with a subnet for nodes and a subnet for pods
#

az network vnet create -g ${RESOURCE_GROUP_NAME} --location ${LOCATION} --name ${VNET_NAME} --address-prefixes ${VNET_ADDRESS_PREFIXES} -o none
az network vnet subnet create -g ${RESOURCE_GROUP_NAME} --vnet-name ${VNET_NAME} --name ${SUBNET_NODE_NAME} --address-prefixes ${SUBNET_NODE_ADDRESS_PREFIXES} -o none
az network vnet subnet create -g ${RESOURCE_GROUP_NAME} --vnet-name ${VNET_NAME} --name ${SUBNET_POD_NAME} --address-prefixes ${SUBNET_POD_ADDRESS_PREFIXES} -o none
az network vnet subnet create -g ${RESOURCE_GROUP_NAME} --vnet-name ${VNET_NAME} --name ${SUBNET_AGIC_NAME} --address-prefixes ${SUBNET_AGIC_ADDRESS_PREFIXES} -o none

#
# Step 3: Create Public IP
#

time az network public-ip create -g ${RESOURCE_GROUP_NAME} --name ${AGIC_PUBLIC_IP_NAME} \
  --sku Standard \
  --location ${LOCATION} \
  --zone 1 2 3

sleep 30

#
# Step 4: Create AGIC with 2 frontend ip: private IP and public ip
#

time az network application-gateway create -g ${RESOURCE_GROUP_NAME} --location ${LOCATION} -n ${AGIC_NAME} \
  --sku Standard_v2 \
  --capacity 1 \
  --public-ip-address ${AGIC_PUBLIC_IP_NAME} \
  --private-ip-address ${AGIC_PRIVATE_IP} \
  --vnet-name ${VNET_NAME} \
  --subnet ${SUBNET_AGIC_NAME} \
  --priority 100 \
  --http2 enabled \
  --zones {1,2,3} \
  --capacity 1


#
# Step 5: Azure Kubernetes Service (AKS)
# Creation: 5 ~ 10m
# https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-create
#

APPGW_ID=$(az network application-gateway show -n ${AGIC_NAME} -g ${RESOURCE_GROUP_NAME} --query "id" -o tsv)

time az aks create -n ${AKS_CLUSTER_NAME} -g ${RESOURCE_GROUP_NAME} -l ${LOCATION} \
  --kubernetes-version ${KUBERNETES_VERSION} \
  --enable-cluster-autoscaler \
  --max-count 2 \
  --min-count 1 \
  --tier premium \
  --max-pods 250 \
  --auto-upgrade-channel stable \
  --k8s-support-plan "AKSLongTermSupport" \
  --dns-name-prefix ${AKS_CLUSTER_NAME} \
  --enable-managed-identity \
  --node-count ${AKS_NODE_COUNT} \
  --node-vm-size ${NODE_VM_SIZE} \
  --network-plugin ${CNI_PLUGIN} \
  --network-policy ${NETWORK_POLICY} \
  --vnet-subnet-id /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}/subnets/${SUBNET_NODE_NAME} \
  --pod-subnet-id /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}/subnets/${SUBNET_POD_NAME} \
  --enable-addons ingress-appgw \
  --appgw-id ${APPGW_ID}


AKS_RESOURCE_GROUPNAME=$(az aks show -n ${AKS_CLUSTER_NAME} -g ${RESOURCE_GROUP_NAME} --query "nodeResourceGroup" -o tsv)

if [ -z "$AKS_RESOURCE_GROUPNAME" ]; then
  echo "AKS_RESOURCE_GROUPNAME is null, exit"
  exit 1
fi

#
# Step 6: Get AKS Credentials
#

az aks get-credentials --admin --overwrite-existing --resource-group ${RESOURCE_GROUP_NAME} \
  --name ${AKS_CLUSTER_NAME} \
  --file ./kubeconfig_${AKS_CLUSTER_NAME}

echo "kubectl cluster-info --kubeconfig=./kubeconfig_${AKS_CLUSTER_NAME}"

#
# Step 999: Wipe Resource Group
#
# az group delete --name ${RESOURCE_GROUP_NAME} --yes --no-wait


# Import kubeconfig to Bastion
# [cloudshell]$ az aks get-credentials --resource-group rg-poc-aks --name poc-aks --file ./kubeconfig_poc-aks
# [cloudshell]$ scp -P 5566 ./kubeconfig_poc-aks repairman@x.x.x.x:/home/repairman/kubeconfig_poc-aks
# [cloudshell]$ ssh repairman@x.x.x.x -p5566
# [bastion]$ export KUBECONFIG=/home/repairman/kubeconfig_poc-aks
# [bastion]$ kubectl cluster-info
#
# Kubernetes control plane is running at https://poc-aks-4iuoo1vw.hcp.eastus.azmk8s.io:443
# CoreDNS is running at https://poc-aks-4iuoo1vw.hcp.eastus.azmk8s.io:443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
# Metrics-server is running at https://poc-aks-4iuoo1vw.hcp.eastus.azmk8s.io:443/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy
#