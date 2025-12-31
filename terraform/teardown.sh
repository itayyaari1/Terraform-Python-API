#!/bin/bash
# Simple teardown script
MY_IP=$(curl -s https://checkip.amazonaws.com)
terraform destroy -var="my_ip=$MY_IP"

