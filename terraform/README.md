# Terraform Deployment

Simple deployment of Python API to AWS EC2.

## Quick Start

### 1. Configure AWS

```bash
aws configure
```

### 2. Deploy

**Option A: Use deploy script (easiest)**
```bash
cd terraform
./deploy.sh
```

**Option B: Manual**
```bash
cd terraform
MY_IP=$(curl -s https://checkip.amazonaws.com)
terraform init
terraform apply -var="my_ip=$MY_IP"
```

### 3. Test API

Wait 2-3 minutes, then:

```bash
PUBLIC_IP=$(terraform output -raw public_ip)

# Test endpoints
curl http://$PUBLIC_IP:5000/status
curl -X POST http://$PUBLIC_IP:5000/update -H "Content-Type: application/json" -d '{"counter": 42, "message": "test"}'
curl http://$PUBLIC_IP:5000/status
curl http://$PUBLIC_IP:5000/logs
```

Or open in browser: `http://$PUBLIC_IP:5000/docs`

### 4. Destroy

**Option A: Use teardown script**
```bash
./teardown.sh
```

**Option B: Manual**
```bash
MY_IP=$(curl -s https://checkip.amazonaws.com)
terraform destroy -var="my_ip=$MY_IP"
```

## Files

- `main.tf` - EC2 instance and security group
- `provider.tf` - AWS provider configuration
- `variables.tf` - Input variables
- `outputs.tf` - Output values (public IP)
- `user_data.sh` - Bootstrap script (installs Docker, builds and runs app)
- `deploy.sh` - Simple deployment script
- `teardown.sh` - Simple teardown script
- `verify_deployment.sh` - Verify API is working after deployment

