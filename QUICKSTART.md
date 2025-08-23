# 🚀 Quick Start Guide

Get your Bazar infrastructure up and running in minutes!

## Prerequisites

1. **AWS CLI** installed and configured
2. **AWS Account** with appropriate permissions
3. **Domain name** and SSL certificate (for HTTPS)

## ⚡ Quick Deploy

### 1. Clone and Setup
```bash
git clone <your-repo-url>
cd bazar-infra
```

### 2. Configure AWS
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter your default region (e.g., us-east-1)
# Enter your default output format (json)
```

### 3. Set Environment Variables
```bash
# Copy example file
cp env.example .env

# Edit with your values
nano .env

# Source the file
source .env
```

**Required variables:**
- `DB_USERNAME`: Database username (default: bazar_admin)
- `DB_PASSWORD`: Database password (you must set this)
- `AWS_PROFILE`: AWS profile to use (recommended: bazar-api)

and then use: 

```bash
# Set the profile for this session
export AWS_PROFILE=bazar-api

# Deploy DEV environment
make deploy-dev
```


### 4. Deploy DEV Environment
```bash
# Deploy everything at once
./scripts/deploy.sh dev

# Or use the Makefile
make deploy-dev
```

### 5. Check Status
```bash
./scripts/status.sh dev
# Or
make status-dev
```

## 🔧 Customization

### Environment Configuration
Edit `config/environments.yaml` to customize:
- Instance types
- Resource sizes
- CIDR ranges
- Scaling parameters

### SSL Certificate
1. Request an SSL certificate in AWS Certificate Manager
2. Update the `SslCertificateArn` parameter in `templates/compute.yaml`
3. Redeploy the compute stack

## 🗑️ Cleanup

### Remove DEV Environment
```bash
./scripts/teardown.sh dev
# Or
make teardown-dev
```

### Remove PROD Environment
```bash
./scripts/teardown.sh prod
# Or
make teardown-prod
```

## 📊 Monitoring

### Check Stack Status
```bash
# All stacks
./scripts/status.sh dev

# Specific stack
./scripts/status.sh dev vpc
./scripts/status.sh dev compute
./scripts/status.sh dev database
```

### Check for Orphaned Resources
```bash
./scripts/teardown.sh dev check
```

## 🚨 Important Notes

1. **Production Safety**: PROD environment requires explicit confirmation for deletion
2. **SSL Required**: HTTPS is mandatory for production use
3. **Database Credentials**: Set DB_USERNAME and DB_PASSWORD environment variables before deployment
4. **Cost Monitoring**: Set up CloudWatch billing alerts
5. **S3 Retention**: S3 buckets (backups and static assets) are retained during teardown to preserve your data

## 🆘 Troubleshooting

### Common Issues

**Stack Creation Fails**
```bash
# Check CloudFormation events
aws cloudformation describe-stack-events --stack-name bazar-vpc-dev

# Validate templates
make validate
```

**ECS Service Won't Start**
```bash
# Check ECS service events
aws ecs describe-services --cluster bazar-cluster-dev --services bazar-api-service-dev

# Check CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix "/ecs/bazar-api-dev"
```

**Database Connection Issues**
```bash
# Check RDS status
aws rds describe-db-instances --db-instance-identifier bazar-postgres-dev

# Check security groups
aws ec2 describe-security-groups --group-names bazar-rds-sg-dev
```

## 🔄 Next Steps

1. **Update DNS**: Point your domain to the ALB endpoint
2. **Configure SSL**: Add your SSL certificate ARN
3. **Deploy Application**: Push your container image to ECR
4. **Set Up Monitoring**: Configure CloudWatch alarms
5. **Backup Strategy**: Test RDS backup and restore procedures

## 📚 Additional Resources

- [README.md](README.md) - Comprehensive documentation
- [AWS CloudFormation User Guide](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/)
- [ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)

---

**Need Help?** Check the main [README.md](README.md) for detailed information and troubleshooting guides. 