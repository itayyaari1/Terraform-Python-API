#!/bin/bash
# Simple deployment script
MY_IP=$(curl -s https://checkip.amazonaws.com)
terraform init
terraform apply -var="my_ip=$MY_IP" -auto-approve

