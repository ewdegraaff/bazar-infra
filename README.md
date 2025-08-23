# Bazar Infrastructure as Code (IaC)

This repository contains CloudFormation templates for deploying the Bazar application infrastructure on AWS. The infrastructure is designed to be deployed as separate environments (DEV/PROD) that can run concurrently.

## 🏗️ Infrastructure Components

### Core Networking
- **VPC**: `10.0.0.0/16` with public and private subnets
- **Public Subnet**: `10.0.0.0/24` - Contains ALB, NAT Gateway, and Internet Gateway
- **Private App Subnet**: `10.0.10.0/24` - Contains ECS Fargate service and VPC endpoints
- **Private Data Subnet**: `10.0.20.0/24` - Contains RDS PostgreSQL instance

### Compute & Application
- **ECS Fargate Cluster**: Hosts the Bazar API service
- **Application Load Balancer**: Internet-facing ALB with HTTPS termination
- **NAT Gateway**: Managed NAT service for outbound internet access from private resources

### Data & Storage
- **RDS PostgreSQL**: Managed database in private subnet
- **S3 Backup Bucket**: Database backups and application data
- **S3 Static Assets Bucket**: Static files, images, and application assets
- **VPC Endpoints**: Secure access to AWS services (S3, ECR, CloudWatch, SSM, Secrets Manager)

### Security
- **Security Groups**: Restrictive access controls between components
- **HTTPS Only**: All external traffic uses TLS encryption
- **Private Subnets**: Application and database resources are not publicly accessible

## 🚀 Deployment Commands

### Prerequisites
- AWS CLI configured with appropriate permissions
- CloudFormation stack creation permissions
- Domain name and SSL certificate (for HTTPS)
- Environment variables set for database credentials

### Environment Variables Setup

**Required Variables:**
```bash
# Database credentials (REQUIRED)
export DB_USERNAME=bazar_admin
export DB_PASSWORD=your_secure_password_here

# AWS profile (recommended)
export AWS_PROFILE=bazar-api
```

**Optional Overrides:**
```bash
# Database settings
export DB_INSTANCE_CLASS=db.t3.micro
export DB_ALLOCATED_STORAGE=20
export DB_MULTI_AZ=false
export DB_BACKUP_RETENTION=7

# Compute settings
export NAT_INSTANCE_TYPE=t3.nano
export ECS_CPU=256
export ECS_MEMORY=512
export ECS_DESIRED_COUNT=1
export ECS_MAX_COUNT=2
```

**Quick Setup:**
```bash
# Copy example file
cp env.example .env

# Edit with your values
nano .env

# Source the file
source .env
```

## 🔒 Environment Variables

Your application environment variables are securely passed through CloudFormation parameters:

### **Required Environment Variables:**
- `DATABASE_URL` - Database connection string
- `SUPABASE_URL` - Supabase project URL  
- `SUPABASE_KEY` - Supabase anon key

### **Optional Environment Variables:**
- `INIT_DB_ON_STARTUP` - Database initialization flag (default: false)
- `INIT_AUTH_ON_STARTUP` - Auth initialization flag (default: false)

### **How It Works:**
1. **Define in `.env` file** - Set your environment variables locally
2. **Automatic pickup** - Deployment script reads `.env` and passes to CloudFormation
3. **Secure deployment** - Values are encrypted in transit and never stored in code

### Deploy Infrastructure

```bash
# Deploy DEV environment
./deploy.sh dev

# Deploy PROD environment
./deploy.sh prod

# Deploy specific stack (optional)
./deploy.sh dev vpc
./deploy.sh dev compute
./deploy.sh dev database
```

### Teardown Infrastructure

```bash
# Remove DEV environment
./teardown.sh dev

# Remove PROD environment
./teardown.sh prod

# Remove specific stack (optional)
./teardown.sh dev database
./teardown.sh dev compute
./teardown.sh dev vpc

# Check for orphaned resources
./teardown.sh dev check
```

### Check Stack Status

```bash
# List all stacks for an environment
./status.sh dev

# Check specific stack status
./status.sh dev vpc
```

## 📁 Project Structure

```
bazar-infra/
├── templates/                 # CloudFormation templates
│   ├── vpc.yaml             # VPC, subnets, route tables
│   ├── compute.yaml         # ECS, ALB, NAT Gateway
│   ├── database.yaml        # RDS, S3, VPC endpoints
│   └── parameters/          # Environment-specific parameters
│       ├── dev.yaml
│       └── prod.yaml
├── scripts/                  # Deployment and utility scripts
│   ├── deploy.sh            # Main deployment script
│   ├── teardown.sh          # Infrastructure removal script
│   └── status.sh            # Stack status checker
├── config/                   # Configuration files
│   └── environments.yaml     # Environment definitions
└── README.md                 # This file
```

## 🔧 Environment Configuration

### Environment Tags
- **DEV**: Development environment with cost-optimized resources
- **PROD**: Production environment with high availability and performance

### Environment Separation
- Each environment gets its own VPC with unique CIDR ranges
- Separate security groups and IAM roles per environment
- Independent scaling and configuration
- Can run concurrently without conflicts

## 💰 Cost Optimization

- **NAT Gateway**: Managed NAT service for reliable outbound internet access
- **Instance Types**: T3 instances for development, optimized for production
- **Storage**: General Purpose SSD for RDS, Intelligent Tiering for S3
- **Auto Scaling**: Configured to scale down during low usage

## 🔒 Security Features

- **Network Isolation**: Private subnets with no direct internet access
- **Security Groups**: Principle of least privilege
- **VPC Endpoints**: Secure AWS service access without internet exposure
- **HTTPS Only**: TLS encryption for all external communications
- **IAM Roles**: Service-specific permissions with minimal scope

## 📊 Monitoring & Logging

- **CloudWatch Logs**: Centralized logging for all services
- **CloudWatch Metrics**: Performance and health monitoring
- **RDS Monitoring**: Database performance insights
- **ALB Access Logs**: Traffic analysis and debugging

## 🚨 Important Notes

1. **SSL Certificate**: You must provide a valid SSL certificate for your domain
2. **Domain Configuration**: Update your DNS to point to the ALB endpoint
3. **Backup Strategy**: RDS backups are enabled by default
4. **Cost Monitoring**: Set up CloudWatch billing alerts
5. **Security Updates**: NAT Gateway is fully managed by AWS
6. **S3 Retention**: S3 backup buckets are configured with `DeletionPolicy: Retain` and will NOT be automatically deleted during teardown

## 🆘 Troubleshooting

### Common Issues
- **Stack Creation Fails**: Check IAM permissions and resource limits
- **ECS Service Won't Start**: Verify security group rules and task definition
- **Database Connection Issues**: Check security groups and subnet configuration
- **ALB Health Check Fails**: Ensure health check endpoint exists in your application

### Support
For infrastructure issues, check CloudFormation events and CloudWatch logs. Application-specific issues should be addressed in the application codebase.

## 🪣 S3 Bucket Management

### Retention Policy
S3 buckets are configured with `DeletionPolicy: Retain` to prevent accidental data loss during infrastructure teardown. This means:

- **Automatic Deletion**: S3 buckets will NOT be deleted when CloudFormation stacks are removed
- **Manual Cleanup**: You must manually delete S3 buckets via AWS Console or CLI if needed
- **Data Preservation**: Your data remains safe during infrastructure changes

### S3 Bucket Types

1. **Database Backup Bucket** (`bazar-db-backups-{env}-{account}`)
   - Stores RDS database backups
   - Lifecycle policies for automatic cleanup of old backups
   - Encrypted with AES256

2. **Static Assets Bucket** (`bazar-static-assets-{env}-{account}`)
   - Stores application static files, images, and assets
   - CORS enabled for web access
   - Versioning enabled for file history
   - Lifecycle policies for old versions



## 🔄 Future Enhancements

- **NAT Gateway**: Already implemented for better reliability
- **Multi-AZ**: Enable RDS Multi-AZ for production
- **Auto Scaling**: Implement ECS service auto-scaling
- **CDN**: Add CloudFront for static content delivery
- **WAF**: Web Application Firewall for enhanced security 





----

#### Check if deleted:

export AWS_PROFILE=bazar-api && aws cloudformation describe-stacks --stack-name bazar-compute-dev --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "Stack deleted"

#### Redeploy:

export AWS_PROFILE=bazar-api && ./scripts/deploy.sh dev compute

#### Force new deployment after image refresh:

export AWS_PROFILE=bazar-api && aws ecs update-service --cluster bazar-cluster-dev --service bazar-api-service-dev --force-new-deployment --output text

#### delete ecs:

export AWS_PROFILE=bazar-api && aws ecs delete-service --cluster bazar-cluster-dev --service bazar-api-service-dev --force --output text

#### delete failed stack: 

export AWS_PROFILE=bazar-api && aws cloudformation delete-stack --stack-name bazar-compute-dev --output text