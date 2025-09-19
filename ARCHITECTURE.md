# LiteLLM Infrastructure Architecture

This document provides a comprehensive overview of the LiteLLM infrastructure architecture, including AWS resources, multi-container deployment, and repository integration patterns.

## 🏗️ System Architecture Overview

```mermaid
graph TB
    subgraph "Internet"
        User[👤 User]
        GitHub[🐙 GitHub Actions]
    end

    subgraph "AWS Cloud"
        subgraph "Public Subnets"
            ALB[🔀 Application Load Balancer<br/>Port 80/443]
            NAT[🌐 NAT Gateway]
        end

        subgraph "Private Subnets"
            subgraph "ECS Fargate Task"
                LiteLLM[📦 LiteLLM Container<br/>Port 4000<br/>PII Guardrails]
                Ollama[🤖 Ollama Container<br/>Port 11434<br/>llama3.2-3b]
            end
        end

        subgraph "Database Subnets"
            RDS[(🗄️ PostgreSQL<br/>db.t3.micro)]
        end

        subgraph "AWS Services"
            ECR[📦 ECR<br/>Custom Images]
            SSM[🔐 SSM Parameter Store<br/>API Keys & Secrets]
            CW[📊 CloudWatch Logs]
            IAM[🔑 IAM Roles & Policies]
        end
    end

    User -->|HTTP/HTTPS| ALB
    ALB -->|Health Checks| LiteLLM
    LiteLLM <-->|localhost:11434| Ollama
    LiteLLM <-->|Database Connection| RDS
    LiteLLM <-->|Secrets| SSM
    GitHub -->|Deploy| ECR
    ECR -->|Pull Images| LiteLLM
    LiteLLM -->|Logs| CW
    Ollama -->|Logs| CW

    classDef container fill:#e1f5fe
    classDef aws fill:#fff3e0
    classDef external fill:#f3e5f5
    
    class LiteLLM,Ollama container
    class ALB,RDS,ECR,SSM,CW,IAM,NAT aws
    class User,GitHub external
```

## 🐳 Multi-Container Architecture

```mermaid
graph LR
    subgraph "ECS Fargate Task"
        subgraph "Shared Network Namespace"
            subgraph "Ollama Container"
                OS[Ollama Server<br/>:11434]
                Model[llama3.2-3b<br/>~2GB Model]
                HC1[Health Check<br/>ollama list]
            end
            
            subgraph "LiteLLM Container"
                API[LiteLLM API<br/>:4000]
                Guards[PII Guardrails<br/>Pre/Post Call]
                Config[Baked Config<br/>litellm-config.yaml]
                HC2[Health Check<br/>curl :4000/health]
            end
        end
    end

    subgraph "External Services"
        OpenAI[🌐 OpenAI API]
        Anthropic[🌐 Anthropic API]
        Azure[🌐 Azure OpenAI]
    end

    API <-->|localhost:11434| OS
    API <-->|API Keys| OpenAI
    API <-->|API Keys| Anthropic
    API <-->|API Keys| Azure
    OS --> Model
    
    classDef local fill:#e8f5e8
    classDef cloud fill:#fff3e0
    classDef health fill:#f3e5f5
    
    class OS,Model,API,Guards,Config local
    class OpenAI,Anthropic,Azure cloud
    class HC1,HC2 health
```

## 🔄 Repository Integration Flow

```mermaid
sequenceDiagram
    participant Dev as 👨‍💻 Developer
    participant AppRepo as 📦 litellm-app
    participant ECR as 🏪 AWS ECR
    participant InfraRepo as 🏗️ litellm-infra
    participant ECS as ☁️ AWS ECS

    Dev->>AppRepo: 1. Push code changes
    AppRepo->>AppRepo: 2. Build container with guardrails
    AppRepo->>ECR: 3. Push tagged image
    AppRepo->>InfraRepo: 4. Repository dispatch event
    
    Note over InfraRepo: Receives image URI + commit SHA
    
    InfraRepo->>InfraRepo: 5. Update task definition
    InfraRepo->>ECS: 6. Deploy new container
    ECS->>ECR: 7. Pull new image
    ECS->>ECS: 8. Start multi-container task
    
    Note over ECS: Ollama pulls model<br/>LiteLLM starts with new config
    
    ECS-->>Dev: 9. Deployment ready
```

## 🌐 Network Architecture

```mermaid
graph TB
    subgraph "VPC: 10.0.0.0/16"
        subgraph "Public Subnets"
            subgraph "AZ-1a: 10.0.1.0/24"
                ALB1[ALB Instance]
                NAT1[NAT Gateway]
            end
            subgraph "AZ-1b: 10.0.2.0/24"
                ALB2[ALB Instance]
            end
        end

        subgraph "Private Subnets"
            subgraph "AZ-1a: 10.0.10.0/24"
                ECS1[ECS Task<br/>LiteLLM + Ollama]
            end
            subgraph "AZ-1b: 10.0.20.0/24"
                ECS2[ECS Task<br/>LiteLLM + Ollama]
            end
        end

        subgraph "Database Subnets"
            subgraph "AZ-1a: 10.0.100.0/24"
                RDS1[RDS Primary]
            end
            subgraph "AZ-1b: 10.0.200.0/24"
                RDS2[RDS Standby]
            end
        end

        IGW[Internet Gateway]
    end

    Internet[🌐 Internet] --> IGW
    IGW --> ALB1
    IGW --> ALB2
    ALB1 --> ECS1
    ALB2 --> ECS2
    ECS1 --> NAT1
    ECS2 --> NAT1
    NAT1 --> IGW
    ECS1 <--> RDS1
    ECS2 <--> RDS1

    classDef public fill:#e3f2fd
    classDef private fill:#f3e5f5
    classDef database fill:#fff3e0
    
    class ALB1,ALB2,NAT1,IGW public
    class ECS1,ECS2 private
    class RDS1,RDS2 database
```

## 🔐 Security Architecture

```mermaid
graph TB
    subgraph "Security Layers"
        subgraph "Network Security"
            SG1[ALB Security Group<br/>Port 80/443<br/>Source: Your IP Only]
            SG2[ECS Security Group<br/>Port 4000<br/>Source: ALB Only]
            SG3[RDS Security Group<br/>Port 5432<br/>Source: ECS Only]
        end

        subgraph "Identity & Access"
            TaskRole[ECS Task Role<br/>SSM Read Access]
            ExecRole[ECS Execution Role<br/>ECR Pull + Logs]
            IAMPol[IAM Policies<br/>Least Privilege]
        end

        subgraph "Secret Management"
            SSMParam[SSM Parameters<br/>SecureString Encryption]
            AutoGen[Auto-Generated Secrets<br/>Master Key, Salt, DB Password]
            APIKeys[API Keys<br/>OpenAI, Anthropic, Azure]
        end

        subgraph "Application Security"
            PIIGuard[PII Guardrails<br/>Regex + Presidio]
            PreCall[Pre-Call Detection<br/>Block Sensitive Input]
            PostCall[Post-Call Detection<br/>Block Sensitive Output]
        end
    end

    SG1 --> SG2
    SG2 --> SG3
    TaskRole --> SSMParam
    ExecRole --> ECR
    SSMParam --> APIKeys
    AutoGen --> SSMParam
    PIIGuard --> PreCall
    PIIGuard --> PostCall

    classDef security fill:#ffebee
    classDef secrets fill:#f3e5f5
    classDef guardrails fill:#e8f5e8
    
    class SG1,SG2,SG3,TaskRole,ExecRole,IAMPol security
    class SSMParam,AutoGen,APIKeys secrets
    class PIIGuard,PreCall,PostCall guardrails
```

## 🚀 CI/CD Pipeline Architecture

```mermaid
graph TB
    subgraph "Development Workflow"
        Dev[👨‍💻 Developer]
        
        subgraph "litellm-app Repository"
            AppCode[Application Code<br/>Guardrails + Config]
            Dockerfile[Dockerfile<br/>Multi-stage Build]
            AppCI[GitHub Actions<br/>Build & Push]
        end
        
        subgraph "litellm-infra Repository"
            TerraformCode[Terraform Modules<br/>Infrastructure as Code]
            InfraCI[GitHub Actions<br/>Deploy & Destroy]
            Environments[Environment Configs<br/>dev, staging, prod]
        end
    end

    subgraph "AWS Infrastructure"
        ECR[AWS ECR<br/>Container Registry]
        ECS[AWS ECS<br/>Multi-Container Tasks]
        
        subgraph "Terraform State"
            S3[S3 Bucket<br/>State Storage]
            DynamoDB[DynamoDB<br/>State Locking]
        end
    end

    Dev -->|1. Code Changes| AppCode
    AppCode --> Dockerfile
    Dockerfile --> AppCI
    AppCI -->|2. Build & Push| ECR
    AppCI -->|3. Repository Dispatch| InfraCI
    
    Dev -->|4. Infrastructure Changes| TerraformCode
    TerraformCode --> InfraCI
    InfraCI <-->|5. State Management| S3
    InfraCI <-->|6. Locking| DynamoDB
    InfraCI -->|7. Deploy| ECS
    ECS <-->|8. Pull Images| ECR

    classDef repo fill:#e3f2fd
    classDef aws fill:#fff3e0
    classDef dev fill:#f3e5f5
    
    class AppCode,Dockerfile,AppCI,TerraformCode,InfraCI,Environments repo
    class ECR,ECS,S3,DynamoDB aws
    class Dev dev
```

## 🔑 Secret Management Flow

```mermaid
graph LR
    subgraph "Secret Sources"
        GHSecrets[GitHub Secrets<br/>OPENAI_API_KEY<br/>AWS_ACCESS_KEY_ID<br/>etc.]
        AutoGen[Auto-Generated<br/>Master Key<br/>Salt Key<br/>DB Password]
    end

    subgraph "Terraform Processing"
        TFVars[terraform.tfvars<br/>additional_ssm_parameters]
        TFRandom[Random Provider<br/>Cryptographic Generation]
    end

    subgraph "AWS Storage"
        SSMStore[SSM Parameter Store<br/>SecureString Encryption]
        KMS[AWS KMS<br/>Encryption Keys]
    end

    subgraph "Container Runtime"
        EnvVars[Environment Variables<br/>OPENAI_API_KEY<br/>LITELLM_MASTER_KEY<br/>DATABASE_URL]
        LiteLLMConfig[LiteLLM Configuration<br/>os.environ/OPENAI_API_KEY]
    end

    GHSecrets --> TFVars
    AutoGen --> TFRandom
    TFVars --> SSMStore
    TFRandom --> SSMStore
    SSMStore <--> KMS
    SSMStore --> EnvVars
    EnvVars --> LiteLLMConfig

    classDef source fill:#e8f5e8
    classDef process fill:#fff3e0
    classDef storage fill:#f3e5f5
    classDef runtime fill:#e3f2fd
    
    class GHSecrets,AutoGen source
    class TFVars,TFRandom process
    class SSMStore,KMS storage
    class EnvVars,LiteLLMConfig runtime
```

## 🤖 Model Routing Architecture

```mermaid
graph TB
    subgraph "Client Request"
        Client[📱 Client Application]
        Request[HTTP Request<br/>model gpt-4o-mini]
    end

    subgraph "LiteLLM Proxy Layer"
        ALB[🔀 Application Load Balancer]
        Auth[🔐 Authentication<br/>Master Key Validation]
        
        subgraph "PII Guardrails"
            PreCall[🛡️ Pre-Call Guardrail<br/>Scan Input for PII]
            PostCall[🛡️ Post-Call Guardrail<br/>Scan Output for PII]
        end
        
        Router[🎯 Model Router<br/>Route to Provider]
    end

    subgraph "Model Providers"
        subgraph "Local Models"
            Ollama[🤖 Ollama Server<br/>localhost:11434]
            LocalModel[🧠 llama3.2-3b<br/>~2GB Model]
        end
        
        subgraph "Cloud Models"
            OpenAI[☁️ OpenAI API<br/>gpt-4o-mini]
            Anthropic[☁️ Anthropic API<br/>claude-3-5-sonnet]
            Azure[☁️ Azure OpenAI<br/>gpt-4o]
        end
    end

    subgraph "Data Layer"
        RDS[(🗄️ PostgreSQL<br/>User Data, Logs, Analytics)]
    end

    Client --> Request
    Request --> ALB
    ALB --> Auth
    Auth --> PreCall
    PreCall --> Router
    
    Router -->|Local Request| Ollama
    Router -->|Cloud Request| OpenAI
    Router -->|Cloud Request| Anthropic
    Router -->|Cloud Request| Azure
    
    Ollama --> LocalModel
    
    OpenAI --> PostCall
    Anthropic --> PostCall
    Azure --> PostCall
    Ollama --> PostCall
    
    PostCall --> Client
    Router --> RDS

    classDef client fill:#e3f2fd
    classDef proxy fill:#fff3e0
    classDef local fill:#e8f5e8
    classDef cloud fill:#f3e5f5
    classDef data fill:#fce4ec
    
    class Client,Request client
    class ALB,Auth,PreCall,PostCall,Router proxy
    class Ollama,LocalModel local
    class OpenAI,Anthropic,Azure cloud
    class RDS data
```

## 🔄 Deployment Flow Architecture

```mermaid
graph TB
    subgraph "Development Process"
        subgraph "litellm-app Repository"
            DevApp[Developer<br/>App Changes]
            ConfigFile[litellm-config.yaml<br/>Model Definitions]
            Guardrails[Guardrail Files<br/>PII Detection Logic]
            DockerBuild[Docker Build<br/>Multi-platform]
        end
        
        subgraph "litellm-infra Repository"
            DevInfra[Developer<br/>Infrastructure Changes]
            TerraformModules[Terraform Modules<br/>AWS Resources]
            EnvConfigs[Environment Configs<br/>API Keys Resources]
        end
    end

    subgraph "CI/CD Pipeline"
        subgraph "App Pipeline"
            AppCI[GitHub Actions<br/>litellm-app]
            ECRPush[ECR Push<br/>Tagged Images]
            RepoDispatch[Repository Dispatch<br/>Trigger Infrastructure]
        end
        
        subgraph "Infrastructure Pipeline"
            InfraCI[GitHub Actions<br/>litellm-infra]
            TerraformPlan[Terraform Plan<br/>Infrastructure Changes]
            TerraformApply[Terraform Apply<br/>Deploy Resources]
        end
    end

    subgraph "AWS Deployment"
        ECR[AWS ECR<br/>Container Images]
        ECS[AWS ECS<br/>Multi-Container Tasks]
        
        subgraph "Running Infrastructure"
            LiveContainers[Live Containers<br/>LiteLLM and Ollama]
            LiveModels[Active Models<br/>Local and Cloud]
        end
    end

    DevApp --> ConfigFile
    DevApp --> Guardrails
    ConfigFile --> DockerBuild
    Guardrails --> DockerBuild
    DockerBuild --> AppCI
    AppCI --> ECRPush
    AppCI --> RepoDispatch
    
    DevInfra --> TerraformModules
    DevInfra --> EnvConfigs
    TerraformModules --> InfraCI
    EnvConfigs --> InfraCI
    RepoDispatch --> InfraCI
    
    InfraCI --> TerraformPlan
    TerraformPlan --> TerraformApply
    ECRPush --> ECR
    TerraformApply --> ECS
    ECR --> ECS
    ECS --> LiveContainers
    LiveContainers --> LiveModels

    classDef dev fill:#e3f2fd
    classDef cicd fill:#fff3e0
    classDef aws fill:#f3e5f5
    classDef live fill:#e8f5e8
    
    class DevApp,DevInfra,ConfigFile,Guardrails,TerraformModules,EnvConfigs dev
    class AppCI,InfraCI,ECRPush,RepoDispatch,TerraformPlan,TerraformApply cicd
    class ECR,ECS aws
    class LiveContainers,LiveModels live
```

## 🛡️ PII Guardrail Architecture

```mermaid
graph TB
    subgraph "PII Detection Pipeline"
        Input[📥 User Input<br/>Chat Message]
        
        subgraph "Pre-Call Guardrails"
            RegexPre[🔍 Regex Detection<br/>Email, SSN, Phone, Credit Card]
            PresidioPre[🧠 Presidio ML Detection<br/>50+ Entity Types]
            PreDecision{🚫 Block Request?}
        end
        
        subgraph "Model Processing"
            ModelCall[🤖 Model Inference<br/>Local or Cloud]
            ModelResponse[📤 Model Response]
        end
        
        subgraph "Post-Call Guardrails"
            RegexPost[🔍 Regex Detection<br/>Output Scanning]
            PresidioPost[🧠 Presidio ML Detection<br/>Response Analysis]
            PostDecision{🚫 Block Response?}
        end
        
        Output[📤 Final Response<br/>PII-Free Content]
        Blocked[🚫 Blocked Response<br/>PII Detected]
    end

    Input --> RegexPre
    Input --> PresidioPre
    RegexPre --> PreDecision
    PresidioPre --> PreDecision
    
    PreDecision -->|✅ Safe| ModelCall
    PreDecision -->|❌ PII Found| Blocked
    
    ModelCall --> ModelResponse
    ModelResponse --> RegexPost
    ModelResponse --> PresidioPost
    RegexPost --> PostDecision
    PresidioPost --> PostDecision
    
    PostDecision -->|✅ Safe| Output
    PostDecision -->|❌ PII Found| Blocked

    classDef input fill:#e3f2fd
    classDef guard fill:#fff3e0
    classDef model fill:#e8f5e8
    classDef decision fill:#ffebee
    classDef output fill:#f3e5f5
    
    class Input input
    class RegexPre,PresidioPre,RegexPost,PresidioPost guard
    class ModelCall,ModelResponse model
    class PreDecision,PostDecision decision
    class Output,Blocked output
```

## 📊 Resource Allocation Architecture

```mermaid
graph TB
    subgraph "ECS Fargate Task Resources"
        subgraph "Total Allocation"
            CPU[2048 CPU Units<br/>2 vCPUs]
            Memory[6144 MB Memory<br/>6 GB RAM]
        end
        
        subgraph "Container Distribution"
            subgraph "Ollama Container"
                OllamaCPU[~1024 CPU<br/>Model Inference]
                OllamaRAM[~3072 MB<br/>llama3.2-3b Model]
            end
            
            subgraph "LiteLLM Container"
                LiteLLMCPU[~1024 CPU<br/>API Processing]
                LiteLLMRAM[~3072 MB<br/>Guardrails + Cache]
            end
        end
    end

    subgraph "Supporting Resources"
        RDS[RDS db.t3.micro<br/>1 vCPU, 1 GB RAM<br/>20-100 GB Storage]
        ALB[Application Load Balancer<br/>Managed Service]
        NAT[NAT Gateway<br/>Managed Service]
    end

    subgraph "Cost Breakdown"
        FargateCost[$78.53/month<br/>ECS Fargate]
        NATCost[$33.30/month<br/>NAT Gateway]
        ALBCost[$19.35/month<br/>Load Balancer]
        RDSCost[$15.92/month<br/>Database]
        TotalCost[$148/month<br/>Total Dev Environment]
    end

    CPU --> OllamaCPU
    CPU --> LiteLLMCPU
    Memory --> OllamaRAM
    Memory --> LiteLLMRAM

    classDef resources fill:#e3f2fd
    classDef containers fill:#fff3e0
    classDef supporting fill:#f3e5f5
    classDef cost fill:#e8f5e8
    
    class CPU,Memory resources
    class OllamaCPU,OllamaRAM,LiteLLMCPU,LiteLLMRAM containers
    class RDS,ALB,NAT supporting
    class FargateCost,NATCost,ALBCost,RDSCost,TotalCost cost
```

## 🔄 Container Lifecycle Management

```mermaid
stateDiagram-v2
    [*] --> Pending: ECS Task Created
    
    Pending --> Provisioning: Resources Allocated
    Provisioning --> Starting: Containers Initializing
    
    state Starting {
        [*] --> OllamaStarting: Ollama Container Starts
        OllamaStarting --> ModelPulling: ollama serve starts
        ModelPulling --> OllamaHealthy: llama3.2-3b downloaded
        
        OllamaHealthy --> LiteLLMStarting: Dependency satisfied
        LiteLLMStarting --> ConfigLoading: Load baked config
        ConfigLoading --> LiteLLMHealthy: API server ready
    }
    
    Starting --> Running: Both containers healthy
    
    state Running {
        [*] --> Serving: Ready for requests
        Serving --> Processing: Handle API calls
        Processing --> Serving: Return responses
        
        Serving --> Updating: New image deployed
        Updating --> Serving: Rolling update complete
    }
    
    Running --> Stopping: Scale down or update
    Stopping --> Stopped: Containers terminated
    Stopped --> [*]: Task cleaned up
    
    Running --> Failed: Health check failure
    Failed --> Stopping: Auto-recovery attempt
```

## 🌍 Multi-Environment Architecture

```mermaid
graph TB
    subgraph "Environment Isolation"
        subgraph "Development"
            DevWS[dev workspace]
            DevCIWS[dev-ci workspace]
            DevResources[Single AZ<br/>Cost Optimized<br/>No Deletion Protection]
        end
        
        subgraph "Staging"
            StagingWS[staging workspace]
            StagingResources[Multi AZ<br/>Production-like<br/>Performance Testing]
        end
        
        subgraph "Production"
            ProdWS[prod workspace]
            ProdResources[Multi AZ<br/>High Availability<br/>Deletion Protection]
        end
    end

    subgraph "Shared Resources"
        TerraformState[S3 State Bucket<br/>Workspace Isolation]
        DynamoLocks[DynamoDB Locks<br/>Concurrent Protection]
        ECRRegistry[ECR Registry<br/>Shared Images]
    end

    DevWS --> TerraformState
    DevCIWS --> TerraformState
    StagingWS --> TerraformState
    ProdWS --> TerraformState
    
    DevWS --> DynamoLocks
    DevCIWS --> DynamoLocks
    StagingWS --> DynamoLocks
    ProdWS --> DynamoLocks
    
    DevResources --> ECRRegistry
    StagingResources --> ECRRegistry
    ProdResources --> ECRRegistry

    classDef dev fill:#e8f5e8
    classDef staging fill:#fff3e0
    classDef prod fill:#ffebee
    classDef shared fill:#f3e5f5
    
    class DevWS,DevCIWS,DevResources dev
    class StagingWS,StagingResources staging
    class ProdWS,ProdResources prod
    class TerraformState,DynamoLocks,ECRRegistry shared
```

## 🔍 Request Flow Architecture

```mermaid
sequenceDiagram
    participant Client as 📱 Client
    participant ALB as 🔀 ALB
    participant LiteLLM as 📦 LiteLLM
    participant Guardrails as 🛡️ Guardrails
    participant Ollama as 🤖 Ollama
    participant OpenAI as ☁️ OpenAI
    participant RDS as 🗄️ Database

    Client->>ALB: POST /v1/chat/completions
    ALB->>LiteLLM: Route request
    LiteLLM->>LiteLLM: Validate API key
    LiteLLM->>Guardrails: Pre-call PII scan
    
    alt PII Detected
        Guardrails-->>Client: 400 Bad Request (PII blocked)
    else Safe Input
        Guardrails->>LiteLLM: Input approved
        
        alt Local Model Request
            LiteLLM->>Ollama: Forward to localhost:11434
            Ollama->>Ollama: llama3.2-3b inference
            Ollama-->>LiteLLM: Model response
        else Cloud Model Request
            LiteLLM->>OpenAI: Forward with API key
            OpenAI-->>LiteLLM: Model response
        end
        
        LiteLLM->>Guardrails: Post-call PII scan
        
        alt Response PII Detected
            Guardrails-->>Client: 400 Bad Request (PII blocked)
        else Safe Response
            Guardrails->>LiteLLM: Response approved
            LiteLLM->>RDS: Log request/response
            LiteLLM-->>Client: Final response
        end
    end
```

## 🏷️ Image Tagging Strategy

```mermaid
graph LR
    subgraph "litellm-app Build Process"
        Commit[Git Commit<br/>abc123def]
        Build[Docker Build<br/>Multi-platform]
        
        subgraph "Image Tags"
            Latest[latest<br/>Development]
            CommitTag[abc123def<br/>Immutable]
            BuildNum[build-456<br/>Sequential]
        end
    end

    subgraph "Deployment Strategies"
        subgraph "Manual Deployment"
            ManualTrigger[Manual Trigger]
            UseLatest[Use 'latest' tag]
        end
        
        subgraph "Repository Dispatch"
            AutoTrigger[Auto Trigger]
            UseCommit[Use commit SHA tag]
        end
        
        subgraph "Rollback Strategy"
            RollbackTrigger[Rollback Needed]
            UsePrevious[Use previous commit/build]
        end
    end

    Commit --> Build
    Build --> Latest
    Build --> CommitTag
    Build --> BuildNum
    
    ManualTrigger --> UseLatest
    AutoTrigger --> UseCommit
    RollbackTrigger --> UsePrevious
    
    Latest --> ECRDeploy[ECR Deployment]
    CommitTag --> ECRDeploy
    BuildNum --> ECRDeploy

    classDef build fill:#e3f2fd
    classDef tags fill:#fff3e0
    classDef deploy fill:#e8f5e8
    
    class Commit,Build build
    class Latest,CommitTag,BuildNum tags
    class ManualTrigger,AutoTrigger,RollbackTrigger,UseLatest,UseCommit,UsePrevious,ECRDeploy deploy
```

## 🔧 Infrastructure Components

### **AWS Resources Created:**

| Component | Resource Type | Purpose | Configuration |
|-----------|---------------|---------|---------------|
| **VPC** | aws_vpc | Network isolation | 10.0.0.0/16 CIDR |
| **Subnets** | aws_subnet | Network segmentation | Public, Private, Database |
| **Internet Gateway** | aws_internet_gateway | Internet access | Single per VPC |
| **NAT Gateway** | aws_nat_gateway | Outbound internet for private subnets | Single for cost optimization |
| **Application Load Balancer** | aws_lb | Traffic distribution | Internet-facing |
| **Target Group** | aws_lb_target_group | Health checks and routing | Port 4000 |
| **ECS Cluster** | aws_ecs_cluster | Container orchestration | Fargate with Container Insights |
| **ECS Service** | aws_ecs_service | Service management | Multi-container task definition |
| **ECS Task Definition** | aws_ecs_task_definition | Container specifications | LiteLLM + Ollama containers |
| **RDS Instance** | aws_db_instance | Database | PostgreSQL 15.8, db.t3.micro |
| **Security Groups** | aws_security_group | Network access control | ALB, ECS, RDS, VPC endpoints |
| **IAM Roles** | aws_iam_role | Service permissions | Task role, Execution role |
| **SSM Parameters** | aws_ssm_parameter | Secret storage | Master key, API keys, DB URL |
| **CloudWatch Log Groups** | aws_cloudwatch_log_group | Centralized logging | Separate streams per container |

### **Resource Dependencies:**

```mermaid
graph TB
    VPC[VPC] --> Subnets[Subnets]
    VPC --> SecurityGroups[Security Groups]
    Subnets --> NAT[NAT Gateway]
    Subnets --> ALB[Application Load Balancer]
    Subnets --> ECS[ECS Service]
    Subnets --> RDS[RDS Instance]
    
    SecurityGroups --> ALB
    SecurityGroups --> ECS
    SecurityGroups --> RDS
    
    IAMRoles[IAM Roles] --> ECS
    SSMParameters[SSM Parameters] --> ECS
    ALB --> ECS
    RDS --> ECS
    
    ECR[ECR Images] --> ECS
    CloudWatch[CloudWatch Logs] --> ECS

    classDef network fill:#e3f2fd
    classDef compute fill:#fff3e0
    classDef storage fill:#f3e5f5
    classDef security fill:#ffebee
    
    class VPC,Subnets,NAT,ALB network
    class ECS,ECR compute
    class RDS,SSMParameters,CloudWatch storage
    class SecurityGroups,IAMRoles security
```

## 🔄 Container Communication Patterns

```mermaid
graph LR
    subgraph "ECS Task Network Namespace"
        subgraph "LiteLLM Container"
            LiteLLMAPI[LiteLLM API<br/>:4000]
            ConfigRef[Config References<br/>localhost:11434]
        end
        
        subgraph "Ollama Container" 
            OllamaAPI[Ollama API<br/>:11434]
            ModelEngine[Model Engine<br/>llama3.2-3b]
        end
        
        SharedNetwork[Shared Network<br/>localhost interface]
    end

    subgraph "External Communication"
        ALBTraffic[ALB Traffic<br/>Port 4000]
        CloudAPIs[Cloud APIs<br/>OpenAI, Anthropic]
        Database[PostgreSQL<br/>Port 5432]
    end

    ALBTraffic <--> LiteLLMAPI
    LiteLLMAPI <--> SharedNetwork
    SharedNetwork <--> OllamaAPI
    OllamaAPI <--> ModelEngine
    LiteLLMAPI <--> CloudAPIs
    LiteLLMAPI <--> Database
    
    ConfigRef -.->|localhost:11434| SharedNetwork

    classDef container fill:#e3f2fd
    classDef network fill:#fff3e0
    classDef external fill:#f3e5f5
    
    class LiteLLMAPI,ConfigRef,OllamaAPI,ModelEngine container
    class SharedNetwork network
    class ALBTraffic,CloudAPIs,Database external
```

## 📈 Scaling Architecture

```mermaid
graph TB
    subgraph "Auto-Scaling Triggers"
        CPUMetric[CPU Utilization<br/>>70%]
        MemoryMetric[Memory Utilization<br/>>80%]
        RequestMetric[Request Count<br/>>1000/min]
    end

    subgraph "Scaling Actions"
        ScaleOut[Scale Out<br/>Add ECS Tasks]
        ScaleIn[Scale In<br/>Remove ECS Tasks]
    end

    subgraph "Resource Limits"
        MinTasks[Min: 1 Task<br/>Always Running]
        MaxTasks[Max: 10 Tasks<br/>Cost Protection]
        ResourceLimits[Per Task:<br/>2048 CPU, 6144 MB]
    end

    subgraph "Load Distribution"
        ALBRouting[ALB Routing<br/>Round Robin]
        HealthyTargets[Healthy Targets<br/>Only Route to Healthy]
        TaskDistribution[Task Distribution<br/>Across AZs]
    end

    CPUMetric --> ScaleOut
    MemoryMetric --> ScaleOut
    RequestMetric --> ScaleOut
    
    ScaleOut --> MaxTasks
    ScaleIn --> MinTasks
    
    ScaleOut --> ALBRouting
    ALBRouting --> HealthyTargets
    HealthyTargets --> TaskDistribution

    classDef metrics fill:#e3f2fd
    classDef actions fill:#fff3e0
    classDef limits fill:#f3e5f5
    classDef distribution fill:#e8f5e8
    
    class CPUMetric,MemoryMetric,RequestMetric metrics
    class ScaleOut,ScaleIn actions
    class MinTasks,MaxTasks,ResourceLimits limits
    class ALBRouting,HealthyTargets,TaskDistribution distribution
```

## 🎯 Architecture Design Principles

### **Separation of Concerns:**
- **Infrastructure** (litellm-infra): AWS resources, networking, security
- **Application** (litellm-app): Business logic, models, guardrails

### **Security by Design:**
- **Network isolation**: Private subnets, security groups
- **Secret management**: Auto-generated, encrypted storage
- **Access control**: IP restrictions, authentication required
- **Container security**: Non-root execution, health checks

### **Scalability:**
- **Horizontal scaling**: Auto-scaling ECS tasks
- **Vertical scaling**: Configurable CPU/memory allocation
- **Multi-AZ deployment**: High availability across zones
- **Load balancing**: Traffic distribution across healthy targets

### **Observability:**
- **Centralized logging**: CloudWatch Logs with separate streams
- **Health monitoring**: Container and application health checks
- **Metrics**: ECS, ALB, and RDS performance metrics
- **Traceability**: Request logging and audit trails

### **Cost Optimization:**
- **Right-sizing**: Environment-specific resource allocation
- **Single NAT Gateway**: Cost optimization for development
- **Spot instances**: Optional for non-critical workloads
- **Automated cleanup**: Destroy workflows for temporary environments

---

**This architecture provides a production-ready, secure, and scalable foundation for LiteLLM deployment with local AI model serving capabilities and comprehensive PII protection.**
