#!/bin/bash

# This script automates the deployment of the ib-gateway-docker container to AWS.
# It can run the full deployment or just the local build for testing.

# PREREQUISITES:
# 1. Your `~/.ssh/config` file must be configured with the `ib-gateway-trading-platform` host alias.
# 2. Your 1Password SSH Agent must be running and configured.
# 3. You must be logged in to the AWS CLI (`aws configure`).
# 4. A `deploy.conf` file must exist in this directory with your configuration.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# Source the deployment configuration from a separate, git-ignored file.
if [ -f ./deploy.conf ]; then
  echo "Loading configuration from deploy.conf..."
  source ./deploy.conf
else
  echo "ERROR: deploy.conf file not found. Please create it from deploy.conf.example."
  exit 1
fi

# --- Script Variables ---
ECR_IMAGE_TAG="${ECR_REPOSITORY_URL}:latest"
REMOTE_DEPLOY_PATH="/home/ec2-user/ib-gateway/"

# --- Functions ---

build_local() {
  local build_args="$@" # Capture arguments passed to build_local
  echo "
[Step 1/3] Building the Docker image..."
  if [ -n "$PLATFORM" ]; then
    echo "Building for platform: $PLATFORM"
    docker buildx build --platform "$PLATFORM" --build-arg CACHE_BUST=$(date +%s) -t "${ECR_IMAGE_TAG}" -f latest/Dockerfile . --load
  else
    docker-compose build ${build_args} --build-arg CACHE_BUST=$(date +%s)
  fi

  echo "
[Step 2/3] Logging in to Amazon ECR..."
  aws ecr get-login-password --region "${AWS_REGION}" --profile "${AWS_PROFILE}" | docker login --username AWS --password-stdin "${ECR_REPOSITORY_URL}"

  echo "
[Step 3/3] Local build and ECR login complete."
  echo "Image '${ECR_IMAGE_TAG}' is built and ready to be pushed."
}

push_to_ecr() {
  echo "
[Push] Pushing image to ECR..."
  docker push "${ECR_IMAGE_TAG}"
}

deploy_remote() {
  echo "
[Deploy] Copying config and executing deployment on the IB Gateway host..."

  # Copy configuration files
  scp ./docker-compose.yml ./.env ./tws_password.txt ./vnc_server_password.txt ib-gateway-trading-platform:"${REMOTE_DEPLOY_PATH}"
  # Execute remote deployment
  ssh ib-gateway-trading-platform 'bash -s' <<ENDSSH
    set -e # Exit on any error
    cd "${REMOTE_DEPLOY_PATH}"
    
    echo "Setting permissions for secret files..."
    chmod 600 tws_password.txt vnc_server_password.txt

    echo "Logging into ECR on remote host..."
    aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_REPOSITORY_URL}"

    echo "Pulling the latest image from ECR..."
    docker pull "${ECR_IMAGE_TAG}"

    echo "Stopping current container..."
    docker-compose down

    echo "Starting new container..."
    # The remote docker-compose will use the .env file we just copied
    docker-compose up -d

    echo "Deployment complete on remote host."
ENDSSH
}

show_help() {
  echo "Usage: $0 [command]"
  echo ""
  echo "Commands:"
  echo "  build    Builds the Docker image locally and logs into ECR."
  echo "  deploy   Builds, pushes, and deploys the image to the EC2 instance (default)."
  echo "  help     Show this help message."
}

# --- Main Execution ---

case "$1" in
  build)
    shift # Remove 'build' from arguments
    build_local "$@"
    ;;
  deploy)
    build_local
    push_to_ecr
    deploy_remote
    echo "
\nDeployment script finished successfully!"
    ;;
  help)
    show_help
    ;;
  *)
    echo "No command specified, running full deployment..."
    build_local
    push_to_ecr
    deploy_remote
    echo "
\nDeployment script finished successfully!"
    ;;
esac