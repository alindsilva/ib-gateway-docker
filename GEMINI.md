# GEMINI.md

## Project Overview

This project provides a Dockerized environment for running Interactive Brokers (IB) Gateway and Trader Workstation (TWS). It enables users to run these applications in a containerized and automated fashion, without requiring manual intervention.

The core technologies used are:

*   **Docker:** For containerization.
*   **Interactive Brokers Gateway/TWS:** The core trading applications.
*   **IBC (IB Controller):** A tool to control TWS/IB Gateway and simulate user input for automation.
*   **Ubuntu:** The base operating system for the Docker images.
*   **Xvfb:** A virtual framebuffer to run the graphical applications headless.
*   **x11vnc:** A VNC server for optional remote access to the application's user interface.
*   **socat:** A utility for relaying TCP connections to the IB Gateway.
*   **SSH:** For creating secure tunnels to the IB Gateway.

The project is structured to build Docker images for different versions (`stable` and `latest`) of the IB Gateway and TWS. The build process is templatized, allowing for easy updates to new versions.

## Building and Running

The primary way to use this project is through `docker-compose`.

### Running the Application

1.  **Configuration:**
    *   Create a `.env` file in the root of the project to store your IB credentials and other configuration options. The `README.md` file provides a comprehensive list of all available environment variables.
    *   A sample `.env` file is provided in the `README.md`.

2.  **Start the container:**
    *   To start the IB Gateway, run:
        ```bash
        docker-compose up
        ```
    *   To start TWS with a desktop environment, run:
        ```bash
        docker-compose -f tws-docker-compose.yml up
        ```

### Building the Docker Images

The project includes a script to generate the Dockerfiles for different versions.

1.  **Update the version:**
    *   Run the `update.sh` script with the desired channel (`stable` or `latest`) and version number. For example:
        ```bash
        ./update.sh latest 10.40.1a
        ```
    *   This will create the `Dockerfile` and `Dockerfile.tws` in the `latest` directory.

2.  **Build the image:**
    *   You can then build the image using `docker-compose build` or `docker build`.

## Development Conventions

*   **Configuration via Environment Variables:** The container is highly configurable through environment variables. This is the primary way to customize its behavior.
*   **Templated Dockerfiles:** The `Dockerfile.template` and `Dockerfile.tws.template` are used to generate the final Dockerfiles for different versions. This promotes consistency and simplifies updates.
*   **Shell Scripts for Automation:** The project relies heavily on shell scripts for automation, both for building the images (`update.sh`) and for running the application within the container (`run.sh` and other scripts in `image-files/scripts`).
*   **Multi-stage Docker Builds:** The Dockerfiles use a multi-stage build process to keep the final image size small and to separate build-time dependencies from runtime dependencies.
*   **Graceful Shutdown:** The `run.sh` script includes a trap handler to ensure that the application and all its related processes are shut down gracefully when the container is stopped.
