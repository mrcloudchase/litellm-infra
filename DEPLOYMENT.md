# LiteLLM Deployment Guide

This guide provides step-by-step instructions for deploying LiteLLM infrastructure on AWS.

## Pre-deployment Checklist

### 1. Prerequisites
- [ ] AWS CLI installed and configured
- [ ] Terraform >= 1.0 installed
- [ ] Appropriate AWS IAM permissions

**Note**: Secret generation is now fully automated - no manual key generation required!

## Deployment Steps

### Step 1: Repository Setup

1. Clone the repository:
```bash
git clone <your-repo>
cd litellm-infra

# Initialize Terraform
terraform init
```

### Step 2: Workspace Creation

2. Create and configure your workspace:
```bash
# Create workspace for your environment
terraform workspace new dev  # or staging/prod

# Verify workspace
terraform workspace show
terraform workspace list
```

### Step 3: Environment Configuration

3. Configure your environment:
```bash
# Copy configuration template to environment directory
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars

# Edit with your specific values
nano environments/dev/terraform.tfvars
```

4. Update the configuration file:
```hcl
name_prefix = "my-litellm"

default_tags = {
  Environment = "dev"
  Project     = "litellm"
  Owner       = "your-name"
}

# Add your API keys (stored securely in SSM)
additional_ssm_parameters = {
  "openai-api-key" = {
    value       = "sk-proj-your-openai-key-here"
    type        = "SecureString"
    description = "OpenAI API Key for LiteLLM"
  }
  "anthropic-api-key" = {
    value       = "sk-ant-your-anthropic-key-here"
    type        = "SecureString"
    description = "Anthropic API Key for LiteLLM"
  }
}

# Secrets are auto-generated - no manual input needed!
# LiteLLM master key, salt key, and database password will be
# automatically generated using Terraform's random provider
```

### Step 4: Infrastructure Deployment

1. Validate the configuration:
```bash
# Ensure you're in the correct workspace
terraform workspace show

# Validate configuration
terraform validate
```

2. Review the deployment plan:
```bash
terraform plan -var-file="environments/dev/terraform.tfvars"
```

3. Deploy the infrastructure:
```bash
terraform apply -var-file="environments/dev/terraform.tfvars"
```

Type `yes` when prompted to confirm the deployment.

### Step 5: Post-Deployment Verification

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

The deployment automatically uploads the configuration file from `examples/litellm-config.yaml` to S3. To customize:

1. **Edit the configuration file:**
```bash
# Edit the LiteLLM configuration
nano examples/litellm-config.yaml
```

2. **Add your API keys to SSM Parameter Store:**
```bash
# Example: Add OpenAI API key
aws ssm put-parameter \
  --name "/$(terraform output -raw name_prefix)/litellm/openai-api-key" \
  --value "sk-your-openai-api-key" \
  --type "SecureString" \
  --description "OpenAI API Key for LiteLLM"
```

3. **Deploy configuration changes:**
```bash
# Ensure you're in the correct workspace
terraform workspace show

# This uploads the new config and triggers ECS redeployment
terraform apply -var-file="environments/$(terraform workspace show)/terraform.tfvars"
```

4. **Verify configuration deployment:**
```bash
# Check the S3 configuration location
terraform output config_s3_uri

# Verify ECS tasks are using new configuration
aws ecs describe-services --cluster $(terraform output -raw ecs_cluster_name) --services $(terraform output -raw ecs_service_name)
```

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
# Switch to development workspace
terraform workspace select dev

# Configure development environment
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
nano environments/dev/terraform.tfvars

# Deploy to development
terraform plan -var-file="environments/dev/terraform.tfvars"
terraform apply -var-file="environments/dev/terraform.tfvars"
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
# Switch to production workspace
terraform workspace select prod

# Configure production environment
cp environments/prod/terraform.tfvars.example environments/prod/terraform.tfvars
nano environments/prod/terraform.tfvars

# Deploy to production
terraform plan -var-file="environments/prod/terraform.tfvars"
terraform apply -var-file="environments/prod/terraform.tfvars"
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

### Updating LiteLLM Configuration

The primary method for configuring LiteLLM is through the configuration file:

1. **Edit Configuration File:**
```bash
# Edit the main configuration
nano examples/litellm-config.yaml

# Add new models, change settings, update configurations
```

2. **Deploy Changes:**
```bash
# Upload new config and trigger rolling deployment
terraform apply

# Changes are automatically deployed with zero downtime
```

### Adding Model Providers

#### Method 1: Configuration File (Recommended)
Edit `examples/litellm-config.yaml`:

```yaml
model_list:
  # Add new models
  - model_name: claude-3-5-sonnet
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
  
  - model_name: azure-gpt-4o
    litellm_params:
      model: azure/gpt-4o
      api_base: os.environ/AZURE_API_BASE
      api_key: os.environ/AZURE_API_KEY
      api_version: "2024-02-01"
```

#### Method 2: SSM Parameters
Add API keys via SSM Parameter Store:

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

Then deploy the configuration:
```bash
# Deploy using current workspace configuration
terraform apply -var-file="environments/$(terraform workspace show)/terraform.tfvars"
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
terraform apply -var-file="environments/$(terraform workspace show)/terraform.tfvars"
```

## Monitoring and Maintenance

### Configuration File Management

```bash
# View current configuration in S3
aws s3 cp $(terraform output -raw config_s3_uri) - 

# List configuration versions
aws s3api list-object-versions --bucket $(terraform output -raw config_bucket_name) --prefix litellm-config.yaml

# Download a specific version
aws s3api get-object --bucket $(terraform output -raw config_bucket_name) --key litellm-config.yaml --version-id VERSION_ID config.yaml
```

### Viewing Logs

```bash
# View ECS logs
aws logs tail $(terraform output -raw ecs_log_group_name) --follow

# View specific task logs
aws logs filter-log-events \
  --log-group-name $(terraform output -raw ecs_log_group_name) \
  --start-time $(date -d '1 hour ago' +%s)000

# Check for configuration-related errors
aws logs filter-log-events \
  --log-group-name $(terraform output -raw ecs_log_group_name) \
  --filter-pattern "config"
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
   - Ensure S3 config file is accessible and valid

2. **Configuration File Issues**
   - Verify config file syntax is valid YAML
   - Check S3 bucket permissions for ECS task role
   - Ensure config file exists in S3 bucket
   - Review environment variables for S3 bucket/key names

3. **Database Connection Issues**
   - Verify security group allows connections from ECS
   - Check database endpoint and credentials
   - Ensure database is in available state

4. **Load Balancer Health Checks Failing**
   - Verify the health check path is correct
   - Check that the application is listening on the correct port
   - Review security group rules
   - Ensure config file is properly loaded

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

# Verify configuration file in container
aws ecs execute-command \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --task TASK_ID \
  --container litellm \
  --interactive \
  --command "cat /app/config.yaml"
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
