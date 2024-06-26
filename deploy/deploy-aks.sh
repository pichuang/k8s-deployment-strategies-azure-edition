#!/bin/bash
set -x

az config set extension.use_dynamic_install=yes_without_prompt
az extension add --name aks-preview
az extension update --name aks-preview
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.AlertsManagement
az feature register --namespace "Microsoft.ContainerService" --name "AzureServiceMeshPreview"

#
# Variables for Azure Kubernetes Service (AKS)
#


# SUBSCRIPTION_ID="xxx-xxx-xxx-xxx"
SUBSCRIPTION_ID=$(az account show | jq -r .id)

AKS_CLUSTER_NAME="aks-demo-eastus2"
AKS_NODE_COUNT=2
RESOURCE_GROUP_NAME="rg-${AKS_CLUSTER_NAME}"
LOCATION="EastUS2"
VNET_NAME="vnet-${AKS_CLUSTER_NAME}"
VNET_ADDRESS_PREFIXES="10.67.0.0/24"
SUBNET_NODE_NAME="subnet-nodepool"
SUBNET_NODE_ADDRESS_PREFIXES="10.67.0.0/126"
SUBNET_POD_NAME="subnet-podpool"
SUBNET_POD_ADDRESS_PREFIXES="10.67.0.0/25"

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
# Variable for Log Analytics Workspace
#
LOG_ANALYTICS_WORKSPACE_NAME="law-${AKS_CLUSTER_NAME}"
LOG_ANALYTICS_WORKSPACE_SKU="PerGB2018"

#
# Variable for Azure Monitor Workspace
#
AZURE_MONITOR_WORKSPACE_NAME="amw-${AKS_CLUSTER_NAME}"
GRAFANA_NAME="grafana-${AKS_CLUSTER_NAME}"

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
# Step 3: Azure Managed Prometheus: Create Azure Monitor workspace
# Creation: ~ 22s

time az resource create -g ${RESOURCE_GROUP_NAME} -l ${LOCATION} \
     --namespace microsoft.monitor \
     --resource-type accounts \
     --name ${AZURE_MONITOR_WORKSPACE_NAME} \
     --properties {}

#
# Step 4: Link to Grafana Instance
#

time az grafana create -g ${RESOURCE_GROUP_NAME} -l ${LOCATION} \
    --name ${GRAFANA_NAME}

#
# Step 5: Azure Kubernetes Service (AKS)
# Creation: 5 ~ 10m
# https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-create
#

time az aks create -n ${AKS_CLUSTER_NAME} -g ${RESOURCE_GROUP_NAME} -l ${LOCATION} \
  --kubernetes-version ${KUBERNETES_VERSION} \
  --enable-cluster-autoscaler \
  --azure-monitor-workspace-resource-id /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/microsoft.monitor/accounts/${AZURE_MONITOR_WORKSPACE_NAME} \
  --grafana-resource-id /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/microsoft.dashboard/grafana/${GRAFANA_NAME} \
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
  --enable-azure-service-mesh \
  --enable-azure-monitor-metrics \
  --enable-addons ingress-appgw \
  --appgw-name ${AGIC_NAME} \
  --appgw-subnet-id /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}/subnets/${SUBNET_AGIC_NAME}


AKS_RESOURCE_GROUPNAME=$(az aks show -n ${AKS_CLUSTER_NAME} -g ${RESOURCE_GROUP_NAME} --query "nodeResourceGroup" -o tsv)

if [ -z "$AKS_RESOURCE_GROUPNAME" ]; then
  echo "AKS_RESOURCE_GROUPNAME is null, exit"
  exit 1
fi

#
# Step 6:  Update existing Application Gateway
#
# https://learn.microsoft.com/en-us/cli/azure/network/application-gateway?view=azure-cli-latest#az-network-application-gateway-update
#

time az network application-gateway update -n ${AGIC_NAME} -g ${AKS_RESOURCE_GROUPNAME} \
  --sku Standard_v2 \
  --capacity 1 \

#
# Step 7: Enable Ingress Gateway for Istio Service Mesh
#

time az aks mesh enable-ingress-gateway --resource-group ${RESOURCE_GROUP_NAME} \
  --name ${AKS_CLUSTER_NAME} \
  --ingress-gateway-type external


#
# Step 8: Get AKS Credentials
#

az aks get-credentials --admin --overwrite-existing --resource-group ${RESOURCE_GROUP_NAME} \
  --name ${AKS_CLUSTER_NAME} \
  --file ./kubeconfig_${AKS_CLUSTER_NAME}

#
# Step 9: Apply prometheus config
#

az aks command invoke \
  --resource-group ${RESOURCE_GROUP_NAME} \
  --name ${AKS_CLUSTER_NAME} \
  --command "kubectl apply -f ama-metrics-prometheus-config.yml" \
  --file ama-metrics-prometheus-config.yml

az aks command invoke \
  --resource-group ${RESOURCE_GROUP_NAME} \
  --name ${AKS_CLUSTER_NAME} \
  --command "kubectl apply -f ama-metrics-settings-configmap.yml" \
  --file ama-metrics-settings-configmap.yml


#
# Import Grafana Dashboard
#

# Create Folder
# az grafana folder create -g ${RESOURCE_GROUP_NAME} -n ${GRAFANA_NAME} --title "Azure Service Mesh Istio"

# Istio Control Plane Dashboard: https://grafana.com/grafana/dashboards/7645-istio-control-plane-dashboard/
# az grafana dashboard import -g ${RESOURCE_GROUP_NAME} -n ${GRAFANA_NAME} --folder "Azure Service Mesh Istio" --definition 7645

# Istio Service Dashboard https://grafana.com/grafana/dashboards/7636-istio-service-dashboard/
# az grafana dashboard import -g ${RESOURCE_GROUP_NAME} -n ${GRAFANA_NAME} --folder "Azure Service Mesh Istio" --definition 7636

# Istio Workload Dashboard https://grafana.com/grafana/dashboards/7630-istio-workload-dashboard/
# az grafana dashboard import -g ${RESOURCE_GROUP_NAME} -n ${GRAFANA_NAME} --folder "Azure Service Mesh Istio" --definition 7630

# Istio Mesh Dashboard https://grafana.com/grafana/dashboards/7639-istio-mesh-dashboard/
# az grafana dashboard import -g ${RESOURCE_GROUP_NAME} -n ${GRAFANA_NAME} --folder "Azure Service Mesh Istio" --definition 7639

# Istio Wasm Extension Dashboard https://grafana.com/grafana/dashboards/13277-istio-wasm-extension-dashboard/
# az grafana dashboard import -g ${RESOURCE_GROUP_NAME} -n ${GRAFANA_NAME} --folder "Azure Service Mesh Istio" --definition 13277

# Istio Performance Dashboard https://grafana.com/grafana/dashboards/11829-istio-performance-dashboard/
# az grafana dashboard import -g ${RESOURCE_GROUP_NAME} -n ${GRAFANA_NAME} --folder "Azure Service Mesh Istio" --definition 11829

#
# Step 10: Show Information
#

APPGW_PIP=$(az network public-ip show --name ${AGIC_NAME}-appgwpip --resource-group ${AKS_RESOURCE_GROUPNAME} --query "ipAddress" -o tsv)

GRAFANA_URL=$(az grafana show -g ${RESOURCE_GROUP_NAME} -n ${GRAFANA_NAME} --query "properties.endpoint" -o tsv)

ISTIO_INGRESS_GATEWAY_PIP=$(kubectl get service -n aks-istio-ingress aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

WEB_APPLICATION_ROUTING_PIP=$(kubectl get service -n app-routing-system nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo
echo "Azure Application Gateway IP: ${APPGW_PIP}"
echo "Azure Managed Grafana URL: ${GRAFANA_URL}"
echo "Istio Ingress Gateway IP: ${ISTIO_INGRESS_GATEWAY_PIP}"
echo "Web Application Routing IP: ${WEB_APPLICATION_ROUTE_PIP}"
echo

#
# (Optional) Azure Container Insight: Create Log Analytics workspace
# https://learn.microsoft.com/en-us/cli/azure/monitor/log-analytics/workspace?view=azure-cli-latest#az-monitor-log-analytics-workspace-create
#
# time az monitor log-analytics workspace create -g ${RESOURCE_GROUP_NAME} -l ${LOCATION} \
#     --workspace-name ${LOG_ANALYTICS_WORKSPACE_NAME} \
#     --sku ${LOG_ANALYTICS_WORKSPACE_SKU} \
#     --ingestion-access Enabled \
#     --retention-time 14 \
#     --query-access Enabled


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