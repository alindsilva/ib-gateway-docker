# GEMINI.md

## Project Overview

This project provides a Docker image to run Interactive Brokers Gateway and Trader Workstation (TWS) without human interaction. It is designed for automated trading and can be deployed to the cloud.

The Docker image includes:

*   Interactive Brokers Gateway or TWS
*   IBC to control TWS/IB Gateway
*   Xvfb for running the application in a headless environment
*   x11vnc for optional VNC access
*   socat for relaying TCP connections
*   Optional SSH tunnel for secure connections

The project uses Docker and Docker Compose for containerization and orchestration. The Docker image is based on Ubuntu 24.04 and includes all the necessary dependencies to run the Interactive Brokers software.

## Building and Running

The project can be built and run using Docker Compose.

### Configuration

1.  Create a `.env` file from the `deploy.conf.example` file and populate it with your Interactive Brokers credentials and other configuration options.
2.  The `docker-compose.yml` file defines the `ib-gateway` service and its configuration. Environment variables are used to pass credentials and other settings to the container.

### Building the Image

To build the Docker image, run the following command:

```bash
docker-compose build
```

### Running the Container

To run the container, use the following command:

```bash
docker-compose up
```

The container can also be run in detached mode:

```bash
docker-compose up -d
```

### Deployment

The `deploy.sh` script automates the deployment of the Docker container to AWS. It can be used to build the image locally, push it to Amazon ECR, and deploy it to an EC2 instance.

**Usage:**

*   `./deploy.sh build`: Builds the Docker image locally and logs into ECR.
*   `./deploy.sh deploy`: Builds, pushes, and deploys the image to the EC2 instance.

## Development Conventions

*   The project uses a `Dockerfile.template` to build the Docker image. This template is used to generate the final `Dockerfile` for different versions of the Interactive Brokers software.
*   The `latest` and `stable` directories contain the `Dockerfile` and other files for the latest and stable releases of the Interactive Brokers software.
*   The `image-files` directory contains configuration files and scripts that are copied into the Docker image.
*   The `deploy.sh` script is used for automated deployment to AWS.
*   The project uses GitHub Actions for continuous integration and to detect new releases of the Interactive Brokers software.
