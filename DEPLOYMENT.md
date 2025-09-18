# LiteLLM Deployment Guide

This guide provides step-by-step instructions for deploying LiteLLM infrastructure on AWS.

## Pre-deployment Checklist

### 1. Prerequisites
- [ ] AWS CLI installed and configured
- [ ] Terraform >= 1.0 installed
- [ ] Appropriate AWS IAM permissions

**Note**: Secret generation is now fully automated - no manual key generation required!

## Deployment Steps

### Step 1: Environment Setup

1. Clone the repository:
```bash
git clone <your-repo>
cd litellm-infra
```

2. Choose your environment and copy the configuration:
```bash
# For development
cp environments/dev/terraform.tfvars.example terraform.tfvars

# For production
cp environments/prod/terraform.tfvars.example terraform.tfvars
```

3. Edit `terraform.tfvars` with your values:
```hcl
name_prefix = "my-litellm"

default_tags = {
  Environment = "dev"  # or "prod"
  Project     = "litellm"
  Owner       = "your-name"
}

# Secrets are auto-generated - no manual input needed!
# LiteLLM master key, salt key, and database password will be
# automatically generated using Terraform's random provider
```

### Step 2: Infrastructure Deployment

1. Initialize Terraform:
```bash
terraform init
```

2. Validate the configuration:
```bash
terraform validate
```

3. Review the deployment plan:
```bash
terraform plan
```

4. Deploy the infrastructure:
```bash
terraform apply
```

Type `yes` when prompted to confirm the deployment.

### Step 3: Post-Deployment Verification

1. Get the ALB URL:
```bash
ALB_URL=$(terraform output -raw alb_url)
echo "LiteLLM URL: $ALB_URL"
```

2. Wait for the service to be healthy (may take 5-10 minutes):
```bash
# Check ECS service status
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name) \
  --query 'services[0].deployments[0].status'
```

3. Test the health endpoint:
```bash
curl -f "$ALB_URL/health"
```

4. Test the LiteLLM API:
```bash
# Get the auto-generated master key
MASTER_KEY=$(terraform output -raw litellm_master_key)

# Test the API
curl -X POST "$ALB_URL/v1/models" \
  -H "Authorization: Bearer $MASTER_KEY"
```

### Step 4: Configure LiteLLM Models

1. Add your API keys to SSM Parameter Store:
```bash
# Example: Add OpenAI API key
aws ssm put-parameter \
  --name "/$(terraform output -raw name_prefix)/litellm/openai-api-key" \
  --value "sk-your-openai-api-key" \
  --type "SecureString" \
  --description "OpenAI API Key for LiteLLM"
```

2. Update the ECS task definition to include the new environment variables or restart the service to pick up new SSM parameters.

### Step 5: Access Generated Secrets

Retrieve auto-generated secrets:

```bash
# Get the master key for API authentication
terraform output -raw litellm_master_key

# Get commands to retrieve all secrets from SSM
terraform output secret_retrieval_commands

# Or access directly from SSM
aws ssm get-parameter --name "/my-litellm/litellm/master-key" --with-decryption
```

## Environment-Specific Deployments

### Development Environment

Development environment is optimized for cost and ease of debugging:

```bash
# Use development configuration
cp environments/dev/terraform.tfvars.example terraform.tfvars

# Edit the file with development-specific settings
nano terraform.tfvars

# Deploy
terraform apply
```

Key development features:
- Single NAT Gateway (cost optimization)
- Smaller instance sizes
- ECS Exec enabled for debugging
- No deletion protection
- Auto-generated secrets unique to development

### Production Environment

Production environment is optimized for high availability and security:

```bash
# Use production configuration
cp environments/prod/terraform.tfvars.example terraform.tfvars

# Edit the file with production-specific settings
nano terraform.tfvars

# Deploy
terraform apply
```

Key production features:
- Multiple NAT Gateways for HA
- Larger instance sizes
- Multi-AZ RDS deployment
- Deletion protection enabled
- Restricted network access
- Auto-generated secrets unique to production

## Multi-Environment Management

To manage multiple environments:

### Using Terraform Workspaces

1. Create workspaces:
```bash
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod
```

2. Deploy to each environment:
```bash
# Deploy to dev
terraform workspace select dev
terraform apply -var-file="environments/dev/terraform.tfvars"

# Deploy to staging
terraform workspace select staging
terraform apply -var-file="environments/staging/terraform.tfvars"

# Deploy to prod
terraform workspace select prod
terraform apply -var-file="environments/prod/terraform.tfvars"
```

### Using Separate State Files

Alternatively, use separate directories:

```bash
# Create environment-specific directories
mkdir -p deployments/{dev,staging,prod}

# Copy main files to each environment
for env in dev staging prod; do
  cp main.tf variables.tf outputs.tf deployments/$env/
  cp environments/$env/terraform.tfvars.example deployments/$env/terraform.tfvars
done

# Deploy each environment
cd deployments/dev
terraform init && terraform apply
```

## Configuration Management

### Adding Model Providers

To add new model providers, update the SSM parameters:

```bash
# Add Anthropic API key
aws ssm put-parameter \
  --name "/your-prefix/litellm/anthropic-api-key" \
  --value "sk-ant-your-key" \
  --type "SecureString"

# Add Azure OpenAI configuration
aws ssm put-parameter \
  --name "/your-prefix/litellm/azure-api-key" \
  --value "your-azure-key" \
  --type "SecureString"

aws ssm put-parameter \
  --name "/your-prefix/litellm/azure-api-base" \
  --value "https://your-resource.openai.azure.com/" \
  --type "String"
```

### Scaling Configuration

Update the ECS service scaling parameters:

```hcl
# In terraform.tfvars
ecs_desired_count      = 5
ecs_min_capacity       = 3
ecs_max_capacity       = 20
ecs_enable_autoscaling = true
```

Then apply the changes:
```bash
terraform apply
```

## Monitoring and Maintenance

### Viewing Logs

```bash
# View ECS logs
aws logs tail $(terraform output -raw ecs_log_group_name) --follow

# View specific task logs
aws logs filter-log-events \
  --log-group-name $(terraform output -raw ecs_log_group_name) \
  --start-time $(date -d '1 hour ago' +%s)000
```

### Health Monitoring

```bash
# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw alb_target_group_arn)

# Check ECS service health
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name)
```

### Database Maintenance

```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier $(terraform output -raw database_endpoint | cut -d. -f1)

# View database logs
aws rds describe-db-log-files \
  --db-instance-identifier $(terraform output -raw database_endpoint | cut -d. -f1)
```

## Troubleshooting

### Common Issues

1. **ECS Tasks Failing to Start**
   - Check CloudWatch logs for error messages
   - Verify SSM parameters are accessible
   - Check security group configurations

2. **Database Connection Issues**
   - Verify security group allows connections from ECS
   - Check database endpoint and credentials
   - Ensure database is in available state

3. **Load Balancer Health Checks Failing**
   - Verify the health check path is correct
   - Check that the application is listening on the correct port
   - Review security group rules

### Getting Help

```bash
# Debug ECS task
aws ecs execute-command \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --task TASK_ID \
  --container litellm \
  --interactive \
  --command "/bin/bash"

# Check recent events
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name) \
  --query 'services[0].events[:5]'
```

## Cleanup

To destroy the infrastructure:

```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy the infrastructure
terraform destroy
```

**Important**: If deletion protection is enabled, disable it first:

```bash
# Disable ALB deletion protection
aws elbv2 modify-load-balancer \
  --load-balancer-arn $(terraform output -raw alb_arn) \
  --no-deletion-protection

# Disable RDS deletion protection
aws rds modify-db-instance \
  --db-instance-identifier $(terraform output -raw database_endpoint | cut -d. -f1) \
  --no-deletion-protection
```

## Security Best Practices

1. **Secrets are automatically generated with cryptographic strength**
2. **Restrict network access using security groups**
3. **Enable deletion protection in production**
4. **Secrets are unique per environment and stored securely in SSM**
5. **Monitor access logs and metrics**
6. **Use least-privilege IAM policies**
7. **Enable encryption at rest and in transit**
8. **Rotate secrets by tainting Terraform random resources if needed**

## Performance Optimization

1. **Right-size your instances based on actual usage**
2. **Use appropriate auto-scaling thresholds**
3. **Monitor database performance and optimize queries**
4. **Consider using RDS Proxy for connection pooling**
5. **Enable CloudWatch Container Insights for detailed metrics**
