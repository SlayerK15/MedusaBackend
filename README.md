Medusa Backend Deployment with Terraform and GitHub Actions

Overview
This repository contains configuration files for deploying the Medusa headless commerce backend using AWS ECS/Fargate, managed through Terraform, and automated with GitHub Actions. This setup is designed as a learning project to explore infrastructure as code and CI/CD processes.

Important Disclaimer: I am currently in the process of learning Terraform and AWS services. The configurations in this repository are built through guidance and templates, and I do not have a deep understanding of these tools yet.

Repository Structure
Dockerfile: Sets up the Docker environment for the Medusa backend.
main.tf: Terraform file for creating AWS resources required to run the Medusa backend.
.github/workflows/deploy.yml: GitHub Actions workflow that automates the process of building the Docker image and deploying it to AWS ECS.

File Descriptions
*Dockerfile : 
The Dockerfile is responsible for creating the container image of the Medusa backend. It installs necessary dependencies and configures the server to start upon deployment.
*Terraform Configuration  : 
This file contains the setup for:
AWS ECR: Repository for the Docker image.
AWS Networking: Includes VPC, subnets, and security groups for secure and scalable deployment.
AWS ECS and Fargate: Services that manage the container deployment and scaling.
AWS Load Balancer: Distributes incoming traffic to enhance reliability and performance.
*GitHub Actions Workflow (deploy.yml): 
This CI/CD pipeline automates:
Docker image construction.
Image upload to AWS ECR.
Service update on AWS ECS for rolling out the latest backend version.

Usage and Learning Notes
Terraform: The terraform init command is used to initialize a working directory containing Terraform configuration files. This is part of the setup that I am learning to use correctly.
AWS Services: This project utilizes several AWS services, configured as per provided guides and best practices. Detailed operational knowledge of these services is outside my current expertise.

