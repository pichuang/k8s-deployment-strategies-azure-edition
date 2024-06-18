#!/bin/bash

az aks update --name aks-pichuang-japaneast \
              --resource-group rg-aks-japaneast \
              --outbound-type managedNATGateway \
              --nat-gateway-managed-outbound-ip-count 1 \
              --nat-gateway-idle-timeout 4