# Deployment Guide

## Prerequisites

1. **AWS Account** (Free Tier eligible)
   - Sign up at: https://aws.amazon.com/free/
   - Free tier includes 750 hours/month of t2.micro EC2 instances

2. **AWS CLI configured**
   ```bash
   aws configure
   ```

3. **Terraform installed**
   ```bash
   # macOS
   brew install terraform
   
   # Or download from: https://www.terraform.io/downloads
   ```

## Deployment Steps

### 1. Get Your Public IP

```bash
MY_IP=$(curl -s https://checkip.amazonaws.com)
echo "Your IP: $MY_IP"
```

### 2. Initialize Terraform

```bash
cd terraform
terraform init
```

### 3. Plan the Deployment

```bash
terraform plan -var="my_ip=$MY_IP"
```

### 4. Deploy Infrastructure

```bash
terraform apply -var="my_ip=$MY_IP"
```

This will:
- Create EC2 instance (t2.micro)
- Create Security Group (port 5000, whitelisted to your IP)
- Run user_data.sh script which:
  - Installs Docker
  - Creates application files
  - Builds Docker image
  - Runs container

### 5. Get the Public IP

```bash
terraform output public_ip
```

### 6. Wait for Deployment

The EC2 instance needs 2-3 minutes to:
- Boot up
- Install Docker
- Build the application image
- Start the container

You can monitor the progress by checking the instance status in AWS Console.

### 7. Verify Deployment

**Option A: Use the verification script (recommended)**

```bash
# Get the public IP and verify
PUBLIC_IP=$(terraform output -raw public_ip)
./verify_deployment.sh $PUBLIC_IP
```

**Option B: Manual testing**

```bash
PUBLIC_IP=$(terraform output -raw public_ip)

# Test status endpoint
curl http://$PUBLIC_IP:5000/status | python3 -m json.tool

# Test update endpoint
curl -X POST http://$PUBLIC_IP:5000/update \
  -H "Content-Type: application/json" \
  -d '{"counter": 42, "message": "Hello from AWS!"}' | python3 -m json.tool

# Test logs endpoint
curl http://$PUBLIC_IP:5000/logs | python3 -m json.tool
```

**Option C: Browser testing**

Open in your browser:
- **Interactive API Docs**: `http://<PUBLIC_IP>:5000/docs` (Best for testing!)
- **Status Endpoint**: `http://<PUBLIC_IP>:5000/status`
- **Logs Endpoint**: `http://<PUBLIC_IP>:5000/logs`

## Troubleshooting

### Check EC2 Instance Status

```bash
# SSH into the instance (if you have key pair configured)
ssh ec2-user@$(terraform output -raw public_ip)

# Check Docker container
sudo docker ps
sudo docker logs python-api
```

### View Cloud Init Logs

```bash
# On the EC2 instance
sudo cat /var/log/cloud-init-output.log
```

## Teardown

To destroy all resources:

```bash
terraform destroy -var="my_ip=$MY_IP"
```

This will:
- Terminate EC2 instance
- Delete Security Group
- Clean up all resources

## Cost Estimate

- **t2.micro EC2**: Free tier (750 hours/month)
- **Data transfer**: Minimal for testing
- **Total cost**: $0 (within free tier limits)

**Note**: Make sure to run `terraform destroy` when done to avoid charges!

