# Bazar Infrastructure Makefile
# Provides convenient shortcuts for common operations

.PHONY: help deploy-dev deploy-prod teardown-dev teardown-prod status-dev status-prod clean

# Default target
help:
	@echo "Bazar Infrastructure Management"
	@echo "=============================="
	@echo ""
	@echo "Available targets:"
	@echo "  deploy-dev          Deploy complete DEV environment"
	@echo "  deploy-prod         Deploy complete PROD environment"
	@echo "  teardown-dev        Remove complete DEV environment"
	@echo "  teardown-prod       Remove complete PROD environment"
	@echo "  status-dev          Show status of DEV environment"
	@echo "  status-prod         Show status of PROD environment"
	@echo "  clean               Remove all temporary files"
	@echo "  setup-env           Set up environment variables from env.example"
	@echo "  test-aws            Test AWS profile configuration"
	@echo "  fix-ecs-role        Fix missing ECS service linked role"
	@echo ""
	@echo "Status Commands (Option 3):"
	@echo "  status-dev-stack    Check DEV CloudFormation stack status"
	@echo "  status-dev-ecs      Check DEV ECS service status"
	@echo "  status-dev-alb      Check DEV ALB status"
	@echo "  status-dev-url      Get DEV API URL"
	@echo "  status-dev-quick    Quick DEV status overview"
	@echo "  status-prod-stack   Check PROD CloudFormation stack status"
	@echo "  status-prod-ecs     Check PROD ECS service status"
	@echo "  status-prod-alb     Check PROD ALB status"
	@echo "  status-prod-url     Get PROD API URL"
	@echo "  status-prod-quick   Quick PROD status overview"
	@echo ""
	@echo "Examples:"
	@echo "  make deploy-dev     # Deploy DEV environment"
	@echo "  make status-prod    # Check PROD environment status"
	@echo "  make teardown-dev   # Remove DEV environment"
	@echo "  make status-dev-url # Get DEV API URL for Route53"

# Deploy environments
deploy-dev:
	@echo "Deploying DEV environment..."
	./scripts/deploy.sh dev

deploy-prod:
	@echo "Deploying PROD environment..."
	./scripts/deploy.sh prod

# Teardown environments
teardown-dev:
	@echo "Removing DEV environment..."
	./scripts/teardown.sh dev

teardown-prod:
	@echo "Removing PROD environment..."
	./scripts/teardown.sh prod



# Status checks
status-dev:
	@echo "Checking DEV environment status..."
	./scripts/status.sh dev

status-prod:
	@echo "Checking PROD environment status..."
	./scripts/status.sh prod

# Individual resource status checks (Option 3)
status-dev-stack:
	@echo "Checking DEV CloudFormation stack status..."
	@export AWS_PROFILE=bazar-api && aws cloudformation describe-stacks --stack-name bazar-compute-dev --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "Stack not found"

status-dev-ecs:
	@echo "Checking DEV ECS service status..."
	@export AWS_PROFILE=bazar-api && aws ecs describe-services --cluster bazar-cluster-dev --services bazar-api-service-dev --query 'services[0].{status: status, runningCount: runningCount, desiredCount: desiredCount, pendingCount: pendingCount}' --output table 2>/dev/null || echo "ECS service not found"

status-dev-alb:
	@echo "Checking DEV ALB status..."
	@export AWS_PROFILE=bazar-api && aws elbv2 describe-load-balancers --names bazar-alb-dev --query 'LoadBalancers[0].{DNSName: DNSName, State: State.Code}' --output table 2>/dev/null || echo "ALB not found"

status-dev-url:
	@echo "DEV API URL:"
	@export AWS_PROFILE=bazar-api && aws elbv2 describe-load-balancers --names bazar-alb-dev --query 'LoadBalancers[0].DNSName' --output text 2>/dev/null || echo "ALB not found"

status-prod-stack:
	@echo "Checking PROD CloudFormation stack status..."
	@export AWS_PROFILE=bazar-api && aws cloudformation describe-stacks --stack-name bazar-compute-prod --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "Stack not found"

status-prod-ecs:
	@echo "Checking PROD ECS service status..."
	@export AWS_PROFILE=bazar-api && aws ecs describe-services --cluster bazar-cluster-prod --services bazar-api-service-prod --query 'services[0].{status: status, runningCount: runningCount, desiredCount: desiredCount, pendingCount: pendingCount}' --output table 2>/dev/null || echo "ECS service not found"

status-prod-alb:
	@echo "Checking PROD ALB status..."
	@export AWS_PROFILE=bazar-api && aws elbv2 describe-load-balancers --names bazar-alb-prod --query 'LoadBalancers[0].{DNSName: DNSName, State: State.Code}' --output table 2>/dev/null || echo "ALB not found"

status-prod-url:
	@echo "PROD API URL:"
	@export AWS_PROFILE=bazar-api && aws elbv2 describe-load-balancers --names bazar-alb-prod --query 'LoadBalancers[0].DNSName' --output text 2>/dev/null || echo "ALB not found"

# Quick status overview
status-dev-quick:
	@echo "=== DEV Environment Quick Status ==="
	@echo "Stack Status:"
	@make status-dev-stack
	@echo ""
	@echo "ECS Service:"
	@make status-dev-ecs
	@echo ""
	@echo "API URL:"
	@make status-dev-url

status-prod-quick:
	@echo "=== PROD Environment Quick Status ==="
	@echo "Stack Status:"
	@make status-prod-stack
	@echo ""
	@echo "ECS Service:"
	@make status-prod-ecs
	@echo ""
	@echo "API URL:"
	@make status-prod-url

# Clean up temporary files
clean:
	@echo "Cleaning up temporary files..."
	@find . -name "*.tmp" -delete
	@find . -name "*.log" -delete
	@echo "Cleanup complete!"

# Validate templates
validate:
	@echo "Validating CloudFormation templates..."
	@for template in templates/*.yaml; do \
		echo "Validating $$template..."; \
		aws cloudformation validate-template --template-body file://$$template || exit 1; \
	done
	@echo "All templates are valid!"

# Show environment configuration
config-dev:
	@echo "DEV Environment Configuration:"
	@cat config/environments.yaml | grep -A 20 "dev:"

config-prod:
	@echo "PROD Environment Configuration:"
	@cat config/environments.yaml | grep -A 20 "prod:"

# Quick deployment of specific stacks
deploy-dev-vpc:
	@echo "Deploying DEV VPC stack..."
	./scripts/deploy.sh dev vpc

deploy-dev-compute:
	@echo "Deploying DEV compute stack..."
	./scripts/deploy.sh dev compute

deploy-dev-database:
	@echo "Deploying DEV database stack..."
	./scripts/deploy.sh dev database

deploy-prod-vpc:
	@echo "Deploying PROD VPC stack..."
	./scripts/deploy.sh prod vpc

deploy-prod-compute:
	@echo "Deploying PROD compute stack..."
	./scripts/deploy.sh prod compute

deploy-prod-database:
	@echo "Deploying PROD database stack..."
	./scripts/deploy.sh prod database

# Environment setup
setup-env:
	@echo "Setting up environment variables..."
	@if [ -f env.example ]; then \
		if [ ! -f .env ]; then \
			cp env.example .env; \
			echo "Created .env file from env.example"; \
			echo "Please edit .env with your actual values:"; \
			echo "  nano .env"; \
			echo "Then source it:"; \
			echo "  source .env"; \
		else \
			echo ".env file already exists. Skipping..."; \
		fi; \
	else \
		echo "env.example not found!"; \
		exit 1; \
	fi

# Test AWS configuration
test-aws:
	@echo "Testing AWS profile configuration..."
	./scripts/test-aws.sh

# Fix ECS service linked role
fix-ecs-role:
	@echo "Fixing ECS service linked role..."
	./scripts/fix-ecs-role.sh

 