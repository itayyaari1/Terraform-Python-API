#!/bin/bash

# Verification script to check that all resources have been destroyed
# Usage: ./verify_teardown.sh

set -e

echo "=========================================="
echo "Verifying Teardown - Checking Resources"
echo "=========================================="
echo ""

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "⚠️  AWS CLI not found. Skipping AWS verification."
    echo "   Please verify manually in AWS Console:"
    echo "   - EC2 Instances: https://console.aws.amazon.com/ec2/"
    echo "   - Security Groups: https://console.aws.amazon.com/ec2/"
    exit 0
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "⚠️  AWS credentials not configured. Skipping AWS verification."
    echo "   Please verify manually in AWS Console."
    exit 0
fi

echo "Checking AWS resources..."
echo ""

# Check EC2 Instances
echo "1. Checking EC2 Instances..."
INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=python-api-instance" "Name=instance-state-name,Values=running,stopped,stopping" \
    --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
    --output text 2>/dev/null || echo "")

if [ -z "$INSTANCES" ] || [ "$INSTANCES" = "None" ]; then
    echo "   ✅ No EC2 instances found"
else
    echo "   ❌ Found EC2 instances:"
    echo "$INSTANCES" | while read line; do
        echo "      $line"
    done
fi

# Check Security Groups
echo ""
echo "2. Checking Security Groups..."
SECURITY_GROUPS=$(aws ec2 describe-security-groups \
    --group-names python-api-sg \
    --query 'SecurityGroups[*].[GroupId,GroupName]' \
    --output text 2>/dev/null || echo "")

if [ -z "$SECURITY_GROUPS" ] || [ "$SECURITY_GROUPS" = "None" ]; then
    echo "   ✅ Security group 'python-api-sg' not found"
else
    echo "   ❌ Found security group:"
    echo "$SECURITY_GROUPS" | while read line; do
        echo "      $line"
    done
fi

# Check Terraform state
echo ""
echo "3. Checking Terraform State..."
if [ -f "terraform.tfstate" ]; then
    STATE_RESOURCES=$(terraform state list 2>/dev/null | wc -l || echo "0")
    if [ "$STATE_RESOURCES" -eq 0 ]; then
        echo "   ✅ Terraform state is empty (no resources tracked)"
    else
        echo "   ⚠️  Terraform state still contains resources:"
        terraform state list 2>/dev/null | head -5
        echo "   (Run 'terraform state list' to see all)"
    fi
else
    echo "   ✅ No Terraform state file found"
fi

echo ""
echo "=========================================="
echo "Verification Complete"
echo "=========================================="
echo ""

# Summary
if [ -z "$INSTANCES" ] && [ -z "$SECURITY_GROUPS" ]; then
    echo "✅ All resources appear to be destroyed!"
    echo ""
    echo "You can also verify in AWS Console:"
    echo "  - EC2: https://console.aws.amazon.com/ec2/"
    echo "  - Security Groups: https://console.aws.amazon.com/ec2/v2/home#SecurityGroups:"
else
    echo "⚠️  Some resources may still exist."
    echo "   Please check the output above and AWS Console."
fi

