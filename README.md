# LiteLLM Infrastructure on AWS

This repository contains a modular Terraform configuration for deploying [LiteLLM](https://docs.litellm.ai/) on AWS using a multi-container ECS setup with local AI model serving capabilities. The infrastructure supports both cloud-based and local AI models with built-in PII detection guardrails.

## 🏗️ Architecture Overview

The deployment creates a production-ready, multi-container setup with:

### **Core Infrastructure:**
- **VPC**: Custom VPC with public, private, and database subnets across multiple AZs
- **ECS Fargate**: Multi-container tasks running LiteLLM + Ollama
- **RDS PostgreSQL**: Database for LiteLLM data persistence
- **Application Load Balancer**: Traffic distribution and SSL termination
- **SSM Parameter Store**: Secure secrets management
- **IAM**: Least-privilege roles and policies
- **CloudWatch**: Centralized logging and monitoring

### **Multi-Container Setup:**
- **LiteLLM Container**: API proxy with PII guardrails (custom ECR image)
- **Ollama Container**: Local AI model server (llama3.2:3b)
- **Shared Networking**: Containers communicate via localhost
- **Resource Allocation**: 2048 CPU, 6144 MB memory for model serving

### **CI/CD Integration:**
- **Repository Dispatch**: Automatic deployments from litellm-app repository
- **GitHub Actions**: Automated infrastructure management
- **Multi-Repository Architecture**: Separation of app and infrastructure concerns

## 📁 Directory Structure

```
litellm-infra/
├── .github/
│   └── workflows/
│       ├── deploy-dev.yml         # CI/CD deployment workflow
│       └── destroy-dev.yml        # Environment cleanup workflow
├── modules/                       # Reusable Terraform modules
│   ├── vpc/                      # VPC and networking resources
│   ├── security-groups/          # Security groups for all components
│   ├── iam/                      # IAM roles and policies
│   ├── ssm/                      # SSM Parameter Store management
│   ├── rds/                      # PostgreSQL database
│   ├── alb/                      # Application Load Balancer
│   └── ecs/                      # Multi-container ECS cluster and service
├── environments/                  # Environment-specific configurations
│   ├── dev/
│   │   └── terraform.tfvars.example
│   ├── staging/
│   │   └── terraform.tfvars.example
│   └── prod/
│       └── terraform.tfvars.example
├── examples/
│   └── backend.tf.example        # Backend configuration template
├── main.tf                       # Main Terraform configuration
├── variables.tf                  # Input variables
├── outputs.tf                    # Output values
├── backend.tf                    # Backend configuration (gitignored)
├── README.md                     # This file
└── DEPLOYMENT.md                 # Detailed deployment guide
```

## 🚀 Quick Start

### Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.0 installed
3. **GitHub CLI** (for CI/CD setup)
4. **AWS IAM permissions** for creating the required resources

### Required AWS Permissions

Your AWS credentials need permissions to create and manage:
- VPC, Subnets, Internet Gateway, NAT Gateway, Route Tables
- ECS Cluster, Service, Task Definition (multi-container)
- RDS Instance, DB Subnet Group, Parameter Group
- Application Load Balancer, Target Group, Listener
- ECR (for custom container registry access)
- IAM Roles and Policies
- SSM Parameters (SecureString)
- Security Groups
- CloudWatch Log Groups

### Setup Terraform Backend (One-time)

```bash
# 1. Generate unique resource names:
BUCKET_NAME="litellm-terraform-state-$(openssl rand -hex 4)"
DYNAMODB_TABLE="litellm-terraform-locks-$(openssl rand -hex 4)"

# 2. Create backend resources manually:
export AWS_REGION="us-east-1"
aws s3api create-bucket --bucket $BUCKET_NAME --region $AWS_REGION
aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket $BUCKET_NAME --server-side-encryption-configuration '{
  "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
}'
aws s3api put-public-access-block --bucket $BUCKET_NAME --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws dynamodb create-table \
  --table-name $DYNAMODB_TABLE \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $AWS_REGION

# 3. Configure Terraform backend:
cp examples/backend.tf.example backend.tf
vim backend.tf  # Update bucket and dynamodb_table values

# 4. Initialize Terraform:
terraform init
```

### Deploy Infrastructure

```bash
# 1. Create workspace:
terraform workspace new dev

# 2. Configure environment:
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
vim environments/dev/terraform.tfvars  # Update with your values

# 3. Deploy:
terraform plan -var-file="environments/dev/terraform.tfvars"
terraform apply -var-file="environments/dev/terraform.tfvars"

# 4. Get deployment information:
terraform output alb_url
terraform output -raw litellm_master_key
```

## 🔄 Multi-Repository Architecture

This infrastructure repository works with a separate `litellm-app` repository:

### **litellm-infra** (This Repository):
- **Purpose**: AWS infrastructure management
- **Contains**: Terraform modules, environment configs, CI/CD workflows
- **Responsibilities**: VPC, ECS, RDS, ALB, security, networking

### **litellm-app** (Separate Repository):
- **Purpose**: Application code and container building
- **Contains**: Dockerfile, guardrails code, LiteLLM config, build workflows
- **Responsibilities**: Container images, PII guardrails, model configurations

### **Integration Flow:**
1. **litellm-app** builds and pushes new container → ECR
2. **Repository dispatch** triggers **litellm-infra** deployment
3. **Infrastructure updates** with new container image
4. **Multi-container deployment** with latest guardrails and models

## 🐳 Multi-Container Configuration

### **Container 1: Ollama (Local AI Model Server)**
- **Image**: `ollama/ollama:latest`
- **Port**: 11434
- **Purpose**: Serves llama3.2:3b model locally
- **Startup**: Automatically pulls and loads the model
- **Health Check**: `ollama list`
- **Resources**: ~3GB memory for model

### **Container 2: LiteLLM (API Proxy + Guardrails)**
- **Image**: Custom ECR image with PII guardrails
- **Port**: 4000 (exposed via ALB)
- **Purpose**: API proxy with PII detection
- **Dependencies**: Waits for Ollama to be healthy
- **Configuration**: Baked into container image
- **API Base**: `http://localhost:11434` for Ollama communication

### **Resource Allocation:**
- **Development**: 2048 CPU, 6144 MB memory
- **Staging**: 2048 CPU, 6144 MB memory  
- **Production**: 4096 CPU, 8192 MB memory

## 🛡️ Security Features

### **Network Security:**
- **Private subnets**: ECS tasks isolated from internet
- **IP restrictions**: ALB access limited to specific CIDR blocks
- **Security groups**: Granular network access control
- **VPC isolation**: Database in dedicated subnets

### **Secret Management:**
- **Auto-generated secrets**: Master key, salt key, database password
- **SSM Parameter Store**: SecureString encryption for all secrets
- **Unique per environment**: Separate secrets for dev/staging/prod
- **No manual secret handling**: Fully automated generation

### **Container Security:**
- **Custom guardrails**: Built-in PII detection (email, SSN, phone, credit card)
- **Non-root execution**: Secure container runtime
- **Health checks**: Automated container health monitoring
- **Least privilege**: Minimal IAM permissions

## 🔧 Configuration Management

### **Environment Variables:**
Core configuration via terraform.tfvars:

```hcl
# Multi-container resource allocation
ecs_cpu    = 2048  # CPU units for both containers
ecs_memory = 6144  # Memory in MB for model serving

# Security configuration
allowed_cidr_blocks = ["68.76.147.104/32"]  # Restrict to your IP

# Container image (automatically managed via repository dispatch)
container_image = "your-account.dkr.ecr.us-east-1.amazonaws.com/litellm-guardrails:latest"
```

### **API Keys:**
```hcl
additional_ssm_parameters = {
  "openai-api-key" = {
    value       = "sk-proj-your-openai-key-here"
    type        = "SecureString"
    description = "OpenAI API Key for LiteLLM"
  }
}
```

### **Model Configuration:**
Model configuration is managed in the litellm-app repository and baked into the container image. The container includes:
- **Cloud models**: OpenAI, Anthropic, etc. via API keys
- **Local models**: llama3.2:3b via Ollama container
- **PII guardrails**: Regex-based detection for sensitive data

## 📊 Cost Breakdown (Monthly)

### **Development Environment:**
- **ECS Fargate** (2048 CPU, 6144 MB): ~$78.53
- **NAT Gateway**: ~$33.30
- **Application Load Balancer**: ~$19.35
- **RDS PostgreSQL** (db.t3.micro): ~$15.92
- **CloudWatch Logs**: ~$0.65
- **ECR Storage**: ~$0.20
- **Total**: **~$148/month**

### **Cost Optimization Options:**
- **Scheduled shutdown**: Run only during work hours (~$96/month)
- **Smaller model**: Use llama3.2:1b instead of 3b (~$133/month)
- **Spot instances**: Use Fargate Spot pricing (~$93/month)

## 🚀 CI/CD Workflows

### **Automated Deployment (deploy-dev.yml):**
**Triggers:**
- Push to main branch (infrastructure changes)
- Manual workflow dispatch
- Repository dispatch from litellm-app (new container images)

**Features:**
- **Smart image selection**: Uses repository dispatch payload or fallback secret
- **Terraform workspace isolation**: Separate dev-ci workspace for CI/CD
- **Health endpoint testing**: Automated verification
- **Deployment traceability**: Shows trigger source and container details

### **Environment Cleanup (destroy-dev.yml):**
**Triggers:**
- Manual workflow dispatch with confirmation

**Features:**
- **Confirmation required**: Must type "DESTROY" to proceed
- **Workspace cleanup**: Removes empty workspaces
- **Resource verification**: Shows what will be destroyed
- **Safety checks**: Prevents accidental destruction

## 🔗 Integration with litellm-app

### **Repository Dispatch Flow:**
1. **litellm-app** builds new container with guardrails
2. **Pushes to ECR** with commit-based tagging
3. **Triggers repository dispatch** with image URI
4. **litellm-infra** receives dispatch and deploys new image
5. **Multi-container task** updates with latest guardrails

### **Image Tagging Strategy:**
- **`latest`**: Most recent build (for manual deployments)
- **`commit-sha`**: Immutable commit-based tags (for traceability)
- **Repository dispatch**: Uses specific commit-sha
- **Manual deployments**: Uses latest from ECR

## 🧪 Testing and Verification

### **Health Checks:**
```bash
# Get ALB URL
ALB_URL=$(terraform output -raw alb_url)

# Test health endpoint (may require authentication)
curl "$ALB_URL/health"

# Test model inference
MASTER_KEY=$(terraform output -raw litellm_master_key)
curl -X POST "$ALB_URL/v1/chat/completions" \
  -H "Authorization: Bearer $MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2-3b",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### **Container Status:**
```bash
# Check multi-container task status
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name)

# Check individual container health
aws ecs describe-tasks \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --tasks $(aws ecs list-tasks --cluster $(terraform output -raw ecs_cluster_name) --query 'taskArns[0]' --output text)
```

## 🔍 Monitoring and Debugging

### **CloudWatch Logs:**
- **LiteLLM logs**: `/ecs/litellm-dev-ci` → `litellm/litellm/task-id`
- **Ollama logs**: `/ecs/litellm-dev-ci` → `ollama/ollama/task-id`

### **Common Commands:**
```bash
# View recent logs
aws logs tail $(terraform output -raw ecs_log_group_name) --follow

# Check Ollama model status
aws logs filter-log-events \
  --log-group-name $(terraform output -raw ecs_log_group_name) \
  --filter-pattern "Model pulled successfully"

# Debug container connectivity
aws logs filter-log-events \
  --log-group-name $(terraform output -raw ecs_log_group_name) \
  --filter-pattern "localhost:11434"
```

## 🔧 Environment Management

### **Workspace-Based Deployment:**
```bash
# Development environment (manual)
terraform workspace select dev
terraform apply -var-file="environments/dev/terraform.tfvars"

# CI/CD environment (automated)
# Uses dev-ci workspace via GitHub Actions
```

### **Environment Isolation:**
- **dev**: Manual development and testing
- **dev-ci**: Automated CI/CD deployments
- **staging**: Pre-production validation
- **prod**: Production environment

## 🛠️ Troubleshooting

### **Common Issues:**

1. **503/502 Errors**: Container startup or health check issues
2. **401 Unauthorized**: Health endpoint requires authentication
3. **Ollama connection**: Check localhost:11434 configuration
4. **Model inference**: Verify llama3.2:3b model is pulled

### **Debug Commands:**
```bash
# Check container status
aws ecs describe-tasks --cluster $(terraform output -raw ecs_cluster_name) \
  --tasks $(aws ecs list-tasks --cluster $(terraform output -raw ecs_cluster_name) --query 'taskArns[0]' --output text)

# View container logs
aws logs get-log-events --log-group-name $(terraform output -raw ecs_log_group_name) \
  --log-stream-name "ollama/ollama/task-id"
```

## 💰 Cost Optimization

### **Development Optimizations:**
- Single NAT Gateway (vs. multiple)
- db.t3.micro RDS instance
- Single AZ deployment
- No deletion protection
- IP-restricted access

### **Resource Scaling:**
Adjust based on usage:
```hcl
# For lighter workloads
ecs_cpu    = 1024
ecs_memory = 4096

# For heavier workloads  
ecs_cpu    = 4096
ecs_memory = 8192
```

## 🔐 Security Best Practices

1. **Automated secret generation** with cryptographic strength
2. **IP-based access restrictions** via security groups
3. **Private subnet deployment** for containers
4. **Encrypted storage** for RDS and SSM parameters
5. **Least-privilege IAM policies**
6. **Container security scanning** via ECR
7. **Network isolation** between components

## 📚 Related Documentation

- **Detailed Deployment Guide**: See [DEPLOYMENT.md](./DEPLOYMENT.md)
- **LiteLLM Documentation**: https://docs.litellm.ai/
- **Ollama Documentation**: https://ollama.ai/
- **AWS ECS Documentation**: https://docs.aws.amazon.com/ecs/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test changes in development environment
4. Update documentation if needed
5. Submit a pull request

## 📄 License

[Add your license information here]

---

**Built for production. Optimized for AI workloads. Secured by design.** 🚀