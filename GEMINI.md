# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This project provides a Docker image to run Interactive Brokers Gateway and Trader Workstation (TWS) without human interaction. It is designed for automated trading and can be deployed to the cloud.

The Docker image includes:
* Interactive Brokers Gateway or TWS
* IBC to control TWS/IB Gateway
* Xvfb for running the application in a headless environment
* x11vnc for optional VNC access
* socat for relaying TCP connections
* Optional SSH tunnel for secure connections

## Key Commands

### Development and Building
```bash
# Build the Docker image locally
docker-compose build

# Build with cache busting
docker-compose build --build-arg CACHE_BUST=$(date +%s)

# Run container locally for testing
docker-compose up

# Run in detached mode
docker-compose up -d

# Stop and clean up
docker-compose down
```

### Deployment
```bash
# Build image and login to ECR only
./deploy.sh build

# Full deployment to AWS (build, push, deploy)
./deploy.sh deploy

# Show help
./deploy.sh help
```

### Development Tools
```bash
# Update Dockerfiles from templates
./update.sh

# Check git status for uncommitted changes
git status --porcelain

# View recent changes to specific files
git --no-pager diff HEAD~5..HEAD -- path/to/file
```

## Architecture Overview

### Template-Based Docker Build System
The project uses a template-based approach to maintain multiple versions:
* `Dockerfile.template` - Base template for IB Gateway
* `Dockerfile.tws.template` - Base template for TWS
* `latest/` and `stable/` directories contain generated Dockerfiles
* Templates are processed to create version-specific builds

### Image Configuration Structure
* `image-files/config/` - Configuration templates for IBC and IB Gateway
  * `ibc/config.ini.tmpl` - IBC configuration template
  * `ibgateway/jts.ini.tmpl` - IB Gateway settings template
* `image-files/scripts/` - Runtime scripts copied into containers
  * `run.sh` - Main container entrypoint with privilege dropping
  * `common.sh` - Shared utilities
  * `run_socat.sh` - TCP relay setup
  * `run_ssh.sh` - SSH tunnel management
* `image-files/tws-scripts/` - TWS-specific scripts

### Deployment Pipeline
The deployment system supports:
* Local development with Docker Compose
* AWS deployment via `deploy.sh` script
* ECR registry for container images
* SSH-based remote deployment to EC2 instances

### Configuration Management
* Environment variables drive container behavior
* `.env` file for local development (created from `deploy.conf.example`)
* `deploy.conf` for production deployment settings
* Support for both paper and live trading modes
* Credential management through files or environment variables

### Multi-Version Support
The project maintains parallel support for:
* IB Gateway vs TWS (Trader Workstation)
* Latest vs Stable releases
* Different IB software versions
* GitHub Actions automatically detect new releases

## Important Files

* `deploy.sh` - AWS deployment automation script
* `docker-compose.yml` - Local development configuration
* `tws-docker-compose.yml` - TWS-specific compose file
* `image-files/scripts/run.sh` - Container entrypoint with user privilege management
* `update.sh` - Updates Dockerfiles from templates
* `.github/dependabot.yml` - Automated dependency updates
