# Quick Start Guide

## Prerequisites Check

```bash
# Check AWS CLI
aws --version

# Check Terraform
terraform version

# Get your public IP
curl -s https://checkip.amazonaws.com
```

## One-Command Deployment

```bash
cd terraform
MY_IP=$(curl -s https://checkip.amazonaws.com)
terraform init
terraform apply -var="my_ip=$MY_IP" -auto-approve
```

## One-Command Verification

```bash
PUBLIC_IP=$(terraform output -raw public_ip)
./verify_deployment.sh $PUBLIC_IP
```

## One-Command Teardown

```bash
MY_IP=$(curl -s https://checkip.amazonaws.com)
terraform destroy -var="my_ip=$MY_IP" -auto-approve
```

## Quick Test URLs

After deployment, replace `<PUBLIC_IP>` with your instance IP:

- **API Docs**: http://<PUBLIC_IP>:5000/docs
- **Status**: http://<PUBLIC_IP>:5000/status
- **Logs**: http://<PUBLIC_IP>:5000/logs

## Common Issues

### API not responding
1. Wait 2-3 minutes after `terraform apply`
2. Check security group allows your IP
3. Verify container is running: `ssh ec2-user@<PUBLIC_IP> 'sudo docker ps'`

### Port 5000 not accessible
- Security group only allows your current IP
- If your IP changed, update security group or redeploy

### Container not starting
- Check logs: `ssh ec2-user@<PUBLIC_IP> 'sudo docker logs python-api'`
- Check cloud-init: `ssh ec2-user@<PUBLIC_IP> 'sudo cat /var/log/cloud-init-output.log'`

