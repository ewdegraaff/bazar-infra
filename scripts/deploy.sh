#!/bin/bash

# Bazar Infrastructure Deployment Script
# Usage: ./deploy.sh <environment> [stack_name]
# Example: ./deploy.sh dev
# Example: ./deploy.sh prod vpc

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

  # Function to check if AWS CLI is configured
  check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if AWS_PROFILE is set
    if [[ -n "$AWS_PROFILE" ]]; then
        print_status "Using AWS profile: $AWS_PROFILE"
        
        # Test the specific profile
        if ! aws sts get-caller-identity --profile "$AWS_PROFILE" --output text &> /dev/null; then
            print_error "AWS CLI profile '$AWS_PROFILE' is not configured or has invalid credentials."
            print_error "Please run 'aws configure --profile $AWS_PROFILE' or check your credentials."
            exit 1
        fi
        
        # Get account info for verification
        local account_id=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query 'Account' --output text)
        local user_arn=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query 'Arn' --output text)
        
        print_success "AWS CLI profile '$AWS_PROFILE' is configured and working."
        print_status "Account ID: $account_id"
        print_status "User ARN: $user_arn"
    else
        print_warning "AWS_PROFILE not set. Using default profile."
        
        if ! aws sts get-caller-identity &> /dev/null; then
            print_error "AWS CLI default profile is not configured. Please run 'aws configure' first."
            print_error "Or set AWS_PROFILE environment variable: export AWS_PROFILE=bazar-api"
            exit 1
        fi
        
        print_success "AWS CLI default profile is configured and working."
    fi
  }

# Function to check if required files exist
check_files() {
    local env=$1
    
    if [[ ! -f "config/environments.yaml" ]]; then
        print_error "config/environments.yaml not found!"
        exit 1
    fi
    
    if [[ ! -f "templates/vpc.yaml" ]]; then
        print_error "templates/vpc.yaml not found!"
        exit 1
    fi
    
    if [[ ! -f "templates/compute.yaml" ]]; then
        print_error "templates/compute.yaml not found!"
        exit 1
    fi
    
    if [[ ! -f "templates/database.yaml" ]]; then
        print_error "templates/database.yaml not found!"
        exit 1
    fi
    
    print_success "All required template files found."
}

# Function to get environment configuration
get_env_config() {
    local env=$1
    local config_file="config/environments.yaml"
    
    # Use yq if available, otherwise use grep (basic parsing)
    if command -v yq &> /dev/null; then
        # Extract environment configuration using yq
        eval "$(yq eval ".environments.$env" "$config_file" -o=shell)"
    else
        # Basic parsing with grep (fallback)
        print_warning "yq not found, using basic parsing. Install yq for better configuration handling."
        
        # Extract VPC CIDR
        VPC_CIDR=$(grep -A 20 "dev:" "$config_file" | grep "cidr:" | head -1 | awk '{print $2}' | tr -d '"')
        PUBLIC_SUBNET1_CIDR=$(grep -A 20 "dev:" "$config_file" | grep "public_subnet1_cidr:" | head -1 | awk '{print $2}' | tr -d '"')
    PUBLIC_SUBNET2_CIDR=$(grep -A 20 "dev:" "$config_file" | grep "public_subnet2_cidr:" | head -1 | awk '{print $2}' | tr -d '"')
        PRIVATE_APP_SUBNET_CIDR=$(grep -A 20 "dev:" "$config_file" | grep "private_app_subnet_cidr:" | head -1 | awk '{print $2}' | tr -d '"')
        PRIVATE_DATA_SUBNET1_CIDR=$(grep -A 20 "dev:" "$config_file" | grep "private_data_subnet1_cidr:" | head -1 | awk '{print $2}' | tr -d '"')
    PRIVATE_DATA_SUBNET2_CIDR=$(grep -A 20 "dev:" "$config_file" | grep "private_data_subnet2_cidr:" | head -1 | awk '{print $2}' | tr -d '"')
        
        # Extract compute configuration
        NAT_INSTANCE_TYPE=$(grep -A 20 "dev:" "$config_file" | grep "nat_instance_type:" | head -1 | awk '{print $2}' | tr -d '"')
        ECS_CPU=$(grep -A 20 "dev:" "$config_file" | grep "ecs_cpu:" | head -1 | awk '{print $2}' | tr -d '"')
        ECS_MEMORY=$(grep -A 20 "dev:" "$config_file" | grep "ecs_memory:" | head -1 | awk '{print $2}' | tr -d '"')
        ECS_DESIRED_COUNT=$(grep -A 20 "dev:" "$config_file" | grep "ecs_desired_count:" | head -1 | awk '{print $2}' | tr -d '"')
        ECS_MAX_COUNT=$(grep -A 20 "dev:" "$config_file" | grep "ecs_max_count:" | head -1 | awk '{print $2}' | tr -d '"')
        
        # Extract database configuration
        DB_INSTANCE_CLASS=$(grep -A 20 "dev:" "$config_file" | grep "instance_class:" | head -1 | awk '{print $2}' | tr -d '"')
        DB_ALLOCATED_STORAGE=$(grep -A 20 "dev:" "$config_file" | grep "allocated_storage:" | head -1 | awk '{print $2}' | tr -d '"')
        DB_MULTI_AZ=$(grep -A 20 "dev:" "$config_file" | grep "multi_az:" | head -1 | awk '{print $2}' | tr -d '"')
        DB_BACKUP_RETENTION=$(grep -A 20 "dev:" "$config_file" | grep "backup_retention:" | head -1 | awk '{print $2}' | tr -d '"')
        
        # Override for prod environment
        if [[ "$env" == "prod" ]]; then
            VPC_CIDR=$(grep -A 20 "prod:" "$config_file" | grep "cidr:" | head -1 | awk '{print $2}' | tr -d '"')
            PUBLIC_SUBNET1_CIDR=$(grep -A 20 "prod:" "$config_file" | grep "public_subnet1_cidr:" | head -1 | awk '{print $2}' | tr -d '"')
        PUBLIC_SUBNET2_CIDR=$(grep -A 20 "prod:" "$config_file" | grep "public_subnet2_cidr:" | head -1 | awk '{print $2}' | tr -d '"')
            PRIVATE_APP_SUBNET_CIDR=$(grep -A 20 "prod:" "$config_file" | grep "private_app_subnet_cidr:" | head -1 | awk '{print $2}' | tr -d '"')
            PRIVATE_DATA_SUBNET1_CIDR=$(grep -A 20 "prod:" "$config_file" | grep "private_data_subnet1_cidr:" | head -1 | awk '{print $2}' | tr -d '"')
    PRIVATE_DATA_SUBNET2_CIDR=$(grep -A 20 "prod:" "$config_file" | grep "private_data_subnet2_cidr:" | head -1 | awk '{print $2}' | tr -d '"')
            
            NAT_INSTANCE_TYPE=$(grep -A 20 "prod:" "$config_file" | grep "nat_instance_type:" | head -1 | awk '{print $2}' | tr -d '"')
            ECS_CPU=$(grep -A 20 "prod:" "$config_file" | grep "ecs_cpu:" | head -1 | awk '{print $2}' | tr -d '"')
            ECS_MEMORY=$(grep -A 20 "prod:" "$config_file" | grep "ecs_memory:" | head -1 | awk '{print $2}' | tr -d '"')
            ECS_DESIRED_COUNT=$(grep -A 20 "prod:" "$config_file" | grep "ecs_desired_count:" | head -1 | awk '{print $2}' | tr -d '"')
            ECS_MAX_COUNT=$(grep -A 20 "prod:" "$config_file" | grep "ecs_max_count:" | head -1 | awk '{print $2}' | tr -d '"')
            
            DB_INSTANCE_CLASS=$(grep -A 20 "prod:" "$config_file" | grep "instance_class:" | head -1 | awk '{print $2}' | tr -d '"')
            DB_ALLOCATED_STORAGE=$(grep -A 20 "prod:" "$config_file" | grep "allocated_storage:" | head -1 | awk '{print $2}' | tr -d '"')
            DB_MULTI_AZ=$(grep -A 20 "prod:" "$config_file" | grep "multi_az:" | head -1 | awk '{print $2}' | tr -d '"')
            DB_BACKUP_RETENTION=$(grep -A 20 "prod:" "$config_file" | grep "backup_retention:" | head -1 | awk '{print $2}' | tr -d '"')
        fi
    fi
    
    print_status "Environment configuration loaded for: $env"
}

# Function to deploy VPC stack
deploy_vpc() {
    local env=$1
    local stack_name="bazar-vpc-$env"
    
    print_status "Deploying VPC stack: $stack_name"
    
    aws cloudformation deploy \
        --template-file templates/vpc.yaml \
        --stack-name "$stack_name" \
        --parameter-overrides \
            Environment="$env" \
            VpcCidr="$VPC_CIDR" \
            PublicSubnet1Cidr="$PUBLIC_SUBNET1_CIDR" \
            PublicSubnet2Cidr="$PUBLIC_SUBNET2_CIDR" \
            PrivateAppSubnetCidr="$PRIVATE_APP_SUBNET_CIDR" \
            PrivateDataSubnet1Cidr="$PRIVATE_DATA_SUBNET1_CIDR" \
            PrivateDataSubnet2Cidr="$PRIVATE_DATA_SUBNET2_CIDR" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --tags \
            Environment="$env" \
            Project="Bazar" \
            Owner="DevOps" \
        --profile "${AWS_PROFILE:-}"
    
    print_success "VPC stack deployed successfully!"
}

  # Function to deploy compute stack
  deploy_compute() {
    local env=$1
    local stack_name="bazar-compute-$env"
    
    print_status "Deploying compute stack: $stack_name"
    
    # Get VPC outputs
    local vpc_id=$(aws cloudformation describe-stacks \
        --stack-name "bazar-vpc-$env" \
        --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' \
        --output text \
        --profile "${AWS_PROFILE:-}")
    
    local public_subnet1_id=$(aws cloudformation describe-stacks \
        --stack-name "bazar-vpc-$env" \
        --query 'Stacks[0].Outputs[?OutputKey==`PublicSubnet1Id`].OutputValue' \
        --output text \
        --profile "${AWS_PROFILE:-}")
    
    local public_subnet2_id=$(aws cloudformation describe-stacks \
        --stack-name "bazar-vpc-$env" \
        --query 'Stacks[0].Outputs[?OutputKey==`PublicSubnet2Id`].OutputValue' \
        --output text \
        --profile "${AWS_PROFILE:-}")
    
    local private_app_subnet_id=$(aws cloudformation describe-stacks \
        --stack-name "bazar-vpc-$env" \
        --query 'Stacks[0].Outputs[?OutputKey==`PrivateAppSubnetId`].OutputValue' \
        --output text \
        --profile "${AWS_PROFILE:-}")
    
    local private_route_table_id=$(aws cloudformation describe-stacks \
        --stack-name "bazar-vpc-$env" \
        --query 'Stacks[0].Outputs[?OutputKey==`PrivateRouteTableId`].OutputValue' \
        --output text \
        --profile "${AWS_PROFILE:-}")
    
    aws cloudformation deploy \
        --template-file templates/compute.yaml \
        --stack-name "$stack_name" \
        --parameter-overrides \
            Environment="$env" \
            VpcId="$vpc_id" \
            PublicSubnet1Id="$public_subnet1_id" \
            PublicSubnet2Id="$public_subnet2_id" \
            PrivateAppSubnetId="$private_app_subnet_id" \
            PrivateRouteTableId="$private_route_table_id" \
            EcsCpu="$ECS_CPU" \
            EcsMemory="$ECS_MEMORY" \
            EcsDesiredCount="$ECS_DESIRED_COUNT" \
            EcsMaxCount="$ECS_MAX_COUNT" \
            SslCertificateArn="" \
            HasSslCertificate="false" \
            DatabaseUrl="${DATABASE_URL:-postgresql://placeholder:placeholder@localhost:5432/placeholder}" \
            SupabaseUrl="${SUPABASE_URL:-}" \
            SupabaseKey="${SUPABASE_KEY:-}" \
            InitDbOnStartup="${INIT_DB_ON_STARTUP:-false}" \
            InitAuthOnStartup="${INIT_AUTH_ON_STARTUP:-false}" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --tags \
            Environment="$env" \
            Project="Bazar" \
            Owner="DevOps" \
        --profile "${AWS_PROFILE:-}"
    
    print_success "Compute stack deployed successfully!"
  }

  # Function to load environment variables from .env file
  load_env_file() {
    local env_file=".env"
    
    if [[ -f "$env_file" ]]; then
        print_status "Loading environment variables from $env_file..."
        set -a  # automatically export all variables
        source "$env_file"
        set +a  # stop automatically exporting
        print_success "Environment variables loaded from $env_file"
    else
        print_warning "No .env file found. Make sure environment variables are set manually."
    fi
  }

  # Function to check required environment variables
  check_required_env_vars() {
    local env=$1
    
    # Check for required environment variables (DATABASE_URL is optional for initial deployment)
    if [[ -z "$DATABASE_URL" ]]; then
        print_warning "DATABASE_URL environment variable is not set - using placeholder."
        print_warning "You'll need to update this after deploying the database stack."
    fi
    
    if [[ -z "$SUPABASE_URL" ]]; then
        print_error "SUPABASE_URL environment variable is not set!"
        print_error "Please set it before running the deployment:"
        print_error "  export SUPABASE_URL=your_supabase_project_url"
        print_error "  OR create a .env file with: make setup-env"
        exit 1
    fi
    
    if [[ -z "$SUPABASE_KEY" ]]; then
        print_error "SUPABASE_KEY environment variable is not set!"
        print_error "Please set it before running the deployment:"
        print_error "  export SUPABASE_KEY=your_supabase_anon_key"
        print_error "  OR create a .env file with: make setup-env"
        exit 1
    fi
    
    print_success "Required environment variables are set."
  }

  # Function to deploy database stack
  deploy_database() {
    local env=$1
    local stack_name="bazar-database-$env"
    
    print_status "Deploying database stack: $stack_name"
    
    # Get VPC outputs
    local vpc_id=$(aws cloudformation describe-stacks \
        --stack-name "bazar-vpc-$env" \
        --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' \
        --output text \
        --profile "${AWS_PROFILE:-}")
    
    local private_app_subnet_id=$(aws cloudformation describe-stacks \
        --stack-name "bazar-vpc-$env" \
        --query 'Stacks[0].Outputs[?OutputKey==`PrivateAppSubnetId`].OutputValue' \
        --output text \
        --profile "${AWS_PROFILE:-}")
    
    local private_data_subnet_id=$(aws cloudformation describe-stacks \
        --stack-name "bazar-vpc-$env" \
        --query 'Stacks[0].Outputs[?OutputKey==`PrivateDataSubnetId`].OutputValue' \
        --output text \
        --profile "${AWS_PROFILE:-}")
    
    # Use the manually created second subnet
    local private_data_subnet2_id="subnet-0490daf9618b1aa31"
    
    local private_route_table_id=$(aws cloudformation describe-stacks \
        --stack-name "bazar-vpc-$env" \
        --query 'Stacks[0].Outputs[?OutputKey==`PrivateRouteTableId`].OutputValue' \
        --output text \
        --profile "${AWS_PROFILE:-}")
    
    # Get ECS security group ID (optional for initial deployment)
    local ecs_security_group_id=""
    if aws cloudformation describe-stacks \
        --stack-name "bazar-compute-$env" \
        --query 'Stacks[0].Outputs[?OutputKey==`EcsSecurityGroupId`].OutputValue' \
        --output text \
        --profile "${AWS_PROFILE:-}" 2>/dev/null; then
        ecs_security_group_id=$(aws cloudformation describe-stacks \
            --stack-name "bazar-compute-$env" \
            --query 'Stacks[0].Outputs[?OutputKey==`EcsSecurityGroupId`].OutputValue' \
            --output text \
            --profile "${AWS_PROFILE:-}")
    fi
    
    # Use environment variables for database credentials
    local db_username="bazar_admin"
    local db_password=""
    
    # Parse DATABASE_URL if available
    if [[ -n "$DATABASE_URL" ]]; then
        # Extract username and password from DATABASE_URL
        # Format: postgresql://username:password@host:port/database
        if [[ "$DATABASE_URL" =~ postgresql://([^:]+):([^@]+)@ ]]; then
            db_username="${BASH_REMATCH[1]}"
            db_password="${BASH_REMATCH[2]}"
        fi
    fi
    
    # Fallback to old environment variables if DATABASE_URL parsing failed
    if [[ -z "$db_password" && -n "$DB_PASSWORD" ]]; then
        db_password="$DB_PASSWORD"
    fi
    if [[ -z "$db_username" && -n "$DB_USERNAME" ]]; then
        db_username="$DB_USERNAME"
    fi
    
    # Validate password
    if [[ -z "$db_password" ]]; then
        print_error "Database password not found in DATABASE_URL or DB_PASSWORD"
        exit 1
    fi
    
    print_status "Using database username: $db_username"
    print_status "Database password: [HIDDEN]"
    
    # Build parameter overrides
    local param_overrides="Environment=$env VpcId=$vpc_id PrivateAppSubnetId=$private_app_subnet_id PrivateDataSubnetId=$private_data_subnet_id PrivateDataSubnet2Id=$private_data_subnet2_id PrivateRouteTableId=$private_route_table_id DbInstanceClass=$DB_INSTANCE_CLASS DbAllocatedStorage=$DB_ALLOCATED_STORAGE DbMultiAz=$DB_MULTI_AZ DbBackupRetention=$DB_BACKUP_RETENTION DbUsername=$db_username DbPassword=$db_password"
    
    # Add ECS security group if available
    if [[ -n "$ecs_security_group_id" ]]; then
        param_overrides="$param_overrides EcsSecurityGroupId=$ecs_security_group_id"
    fi
    
    aws cloudformation deploy \
        --template-file templates/database.yaml \
        --stack-name "$stack_name" \
        --parameter-overrides $param_overrides \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --tags \
            Environment="$env" \
            Project="Bazar" \
            Owner="DevOps" \
        --profile "${AWS_PROFILE:-}"
    
    print_success "Database stack deployed successfully!"
  }

# Function to deploy all stacks
deploy_all() {
    local env=$1
    
    print_status "Deploying complete infrastructure for environment: $env"
    
    deploy_vpc "$env"
    deploy_compute "$env"
    deploy_database "$env"
    
    print_success "Complete infrastructure deployed successfully for environment: $env"
    
    # Display outputs
    print_status "Infrastructure outputs:"
    echo "VPC Stack: bazar-vpc-$env"
    echo "Compute Stack: bazar-compute-$env"
    echo "Database Stack: bazar-database-$env"
    
    # Get ALB DNS name
    local alb_dns=$(aws cloudformation describe-stacks \
        --stack-name "bazar-compute-$env" \
        --query 'Stacks[0].Outputs[?OutputKey==`AlbDnsName`].OutputValue' \
        --output text \
        --profile "${AWS_PROFILE:-}")
    
    if [[ "$alb_dns" != "None" ]]; then
        print_success "Application Load Balancer DNS: $alb_dns"
        print_warning "Remember to update your DNS records and configure SSL certificate!"
    fi
}

# Main script
main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <environment> [stack_name]"
        echo "Environments: dev, prod"
        echo "Stacks: vpc, compute, database, all"
        echo ""
        echo "Examples:"
        echo "  $0 dev                    # Deploy all stacks for dev"
        echo "  $0 prod vpc              # Deploy only VPC stack for prod"
        echo "  $0 dev compute           # Deploy only compute stack for dev"
        exit 1
    fi
    
    local environment=$1
    local stack_name=${2:-"all"}
    
    # Validate environment
    if [[ "$environment" != "dev" && "$environment" != "prod" ]]; then
        print_error "Invalid environment: $environment. Use 'dev' or 'prod'."
        exit 1
    fi
    
    # Validate stack name
    if [[ "$stack_name" != "all" && "$stack_name" != "vpc" && "$stack_name" != "compute" && "$stack_name" != "database" ]]; then
        print_error "Invalid stack name: $stack_name. Use 'vpc', 'compute', 'database', or 'all'."
        exit 1
    fi
    
    print_status "Starting deployment for environment: $environment"
    print_status "Target stack: $stack_name"
    
    # Check prerequisites
    check_aws_cli
    check_files "$environment"
    
    # Load environment variables from .env file
    load_env_file
    
    # Load environment configuration
    get_env_config "$environment"
    
    # Check required environment variables
    check_required_env_vars "$environment"
    
    # Deploy based on stack name
    case $stack_name in
        "vpc")
            deploy_vpc "$environment"
            ;;
        "compute")
            deploy_compute "$environment"
            ;;
        "database")
            deploy_database "$environment"
            ;;
        "all")
            deploy_all "$environment"
            ;;
        *)
            print_error "Unknown stack: $stack_name"
            exit 1
            ;;
    esac
    
    print_success "Deployment completed successfully!"
}

# Run main function with all arguments
main "$@" 