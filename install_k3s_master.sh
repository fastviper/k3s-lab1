#!/bin/bash
set -e

echo "$K3S_SERVER_IP"
echo "$K3S_SETUP_SECRET"

# install docker compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# install kubectl
curl -o /usr/local/bin/kubectl https://amazon-eks.s3-us-west-2.amazonaws.com/1.14.6/2019-08-22/bin/linux/amd64/kubectl

chmod +x /usr/local/bin/docker-compose
chmod +x /usr/local/bin/kubectl

# checks 
docker ps
kubectl get nodes
