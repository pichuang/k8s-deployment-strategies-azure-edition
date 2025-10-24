#!/bin/bash

OPENAI_API_KEY=1234567890

kubectl create secret generic k8sgpt-aoai-secret --from-literal=azure-api-key=${OPENAI_API_KEY} -n k8sgpt-operator-system