#!/bin/bash

# This script automates the deployment of the ib-gateway-docker container to AWS.
# It builds the image, pushes it to ECR, and deploys it on the EC2 instance via SSH.

# PREREQUISITES:
# 1. Your `~/.ssh/config` file must be configured with the `ib-gateway-trading-platform` host alias.
# 2. Your 1Password SSH Agent must be running and configured.
# 3. You must be logged in to the AWS CLI (`aws configure`).

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# These values should be filled from your `terraform output`.
AWS_REGION="us-east-1"
ECR_REPOSITORY_URL="394525343407.dkr.ecr.us-east-1.amazonaws.com/trading-platform-prod-trading-platform"

# --- Script Variables ---
IMAGE_NAME="ghcr.io/gnzsnz/ib-gateway:latest"
ECR_IMAGE_TAG="${ECR_REPOSITORY_URL}:latest"
REMOTE_DEPLOY_PATH="/home/ec2-user/ib-gateway/"

# --- Step 1: Build the Docker Image ---
echo "
[Step 1/5] Building the Docker image..."
docker-compose build

# --- Step 2: Log in to Amazon ECR ---
echo "
[Step 2/5] Logging in to Amazon ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_REPOSITORY_URL}"

# --- Step 3: Tag and Push the Image to ECR ---
echo "
[Step 3/5] Tagging and pushing image to ECR..."
docker tag "${IMAGE_NAME}" "${ECR_IMAGE_TAG}"
docker push "${ECR_IMAGE_TAG}"

# --- Step 4: Copy Config Files to Host ---
echo "
[Step 4/5] Copying configuration files to the IB Gateway host..."
# This command uses the `ib-gateway-trading-platform` alias from your ~/.ssh/config
scp ./docker-compose.yml ./.env ib-gateway-trading-platform:"${REMOTE_DEPLOY_PATH}"

# --- Step 5: Execute Remote Deployment ---
echo "
[Step 5/5] Executing deployment on the IB Gateway host..."
# This command also uses the alias and runs the deployment steps remotely.
ssh ib-gateway-trading-platform 'bash -s' <<ENDSSH
  set -e # Exit on any error
  cd "${REMOTE_DEPLOY_PATH}"

  echo "Logging into ECR on remote host..."
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_REPOSITORY_URL}"

  echo "Pulling the latest image from ECR..."
  # Note: We use the ECR_IMAGE_TAG here which is passed into the script
  docker pull "${ECR_IMAGE_TAG}"

  echo "Stopping current container..."
  docker-compose down

  echo "Starting new container..."
  # The remote docker-compose will use the .env file we just copied
  docker-compose up -d

  echo "Deployment complete on remote host."
ENDSSH

echo "
\nDeployment script finished successfully!"