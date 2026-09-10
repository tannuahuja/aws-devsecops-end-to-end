#!/bin/bash

set -e

echo "=========================================="
echo " Starting DevOps Tools Installation"
echo "=========================================="

# ------------------------------------------
# 1. System update + common packages
# ------------------------------------------

echo ">>> Updating system..."

sudo apt-get update
sudo apt-get upgrade -y

sudo apt-get install -y \
    ca-certificates \
    curl \
    wget \
    unzip \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    fontconfig \
    git \
    jq

# ------------------------------------------
# 2. Java 21
# ------------------------------------------

echo ">>> Installing Java 21..."

sudo apt-get install -y openjdk-21-jre

echo "Java version:"
java --version


# ------------------------------------------
# 3. Jenkins
# ------------------------------------------

echo ">>> Installing Jenkins..."

# Remove old Jenkins repository/key if present
sudo rm -f /etc/apt/sources.list.d/jenkins.list
sudo rm -f /etc/apt/keyrings/jenkins-keyring.asc

sudo mkdir -p /etc/apt/keyrings

# IMPORTANT:
# Jenkins 2026 signing key
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] \
https://pkg.jenkins.io/debian-stable binary/" | \
sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt-get update

sudo apt-get install -y jenkins

sudo systemctl enable jenkins
sudo systemctl start jenkins

echo "Jenkins status:"
sudo systemctl --no-pager status jenkins || true

echo "Jenkins initial password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword || true


# ------------------------------------------
# 4. Docker Engine
# ------------------------------------------

echo ">>> Installing Docker..."

# Remove old Docker packages
sudo apt-get remove -y \
    docker.io \
    docker-doc \
    docker-compose \
    docker-compose-v2 \
    podman-docker \
    containerd \
    runc 2>/dev/null || true

# Docker official GPG key
sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -fsSL \
    https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc

# Docker official repository
echo \
"deb [arch=$(dpkg --print-architecture) \
signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

# Install Docker
sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Add users to Docker group
sudo usermod -aG docker ubuntu
sudo usermod -aG docker jenkins

echo "Docker version:"
sudo docker --version

echo "Docker Compose version:"
sudo docker compose version


# ------------------------------------------
# 5. Terraform
# ------------------------------------------

echo ">>> Installing Terraform..."

# Remove old HashiCorp repository if necessary
sudo rm -f /etc/apt/sources.list.d/hashicorp.list

sudo mkdir -p /usr/share/keyrings

wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

echo \
"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com \
$(. /etc/os-release && echo "$VERSION_CODENAME") main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

sudo apt-get update

sudo apt-get install -y terraform

echo "Terraform version:"
terraform version


# ------------------------------------------
# 6. kubectl
# ------------------------------------------

echo ">>> Installing kubectl..."

cd /tmp

# Automatically get latest stable kubectl
KUBECTL_VERSION=$(curl -L -s \
    https://dl.k8s.io/release/stable.txt)

echo "Installing kubectl $KUBECTL_VERSION"

curl -LO \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"

curl -LO \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"

echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

sudo install -o root -g root -m 0755 \
    kubectl /usr/local/bin/kubectl

rm -f kubectl kubectl.sha256

echo "kubectl version:"
kubectl version --client


# ------------------------------------------
# 7. AWS CLI v2
# ------------------------------------------

echo ">>> Installing AWS CLI v2..."

cd /tmp

rm -rf aws awscliv2.zip

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
    -o awscliv2.zip

unzip -q awscliv2.zip

sudo ./aws/install --update

rm -rf aws awscliv2.zip

echo "AWS CLI version:"
aws --version


# ------------------------------------------
# 8. Trivy
# ------------------------------------------

echo ">>> Installing Trivy..."

sudo rm -f /etc/apt/sources.list.d/trivy.list
sudo rm -f /usr/share/keyrings/trivy.gpg

sudo apt-get install -y wget gnupg

wget -qO - \
    https://aquasecurity.github.io/trivy-repo/deb/public.key | \
    gpg --dearmor | \
    sudo tee /usr/share/keyrings/trivy.gpg > /dev/null

echo \
"deb [signed-by=/usr/share/keyrings/trivy.gpg] \
https://aquasecurity.github.io/trivy-repo/deb generic main" | \
sudo tee /etc/apt/sources.list.d/trivy.list > /dev/null

sudo apt-get update

sudo apt-get install -y trivy

echo "Trivy version:"
trivy --version


# ------------------------------------------
# 9. SonarQube
# ------------------------------------------

echo ">>> Installing SonarQube container..."

# Make sure Docker is running
sudo systemctl start docker

# Pull image
sudo docker pull sonarqube:community

# Remove old container if it exists
sudo docker rm -f sonarqube 2>/dev/null || true

# Start SonarQube
sudo docker run -d \
    --name sonarqube \
    --restart unless-stopped \
    -p 9000:9000 \
    sonarqube:community

echo "SonarQube container:"
sudo docker ps --filter name=sonarqube


# ------------------------------------------
# 10. Final verification
# ------------------------------------------

echo ""
echo "=========================================="
echo " Installation completed!"
echo "=========================================="

echo ""
echo "Java:"
java --version 2>&1 | head -n 1

echo ""
echo "Jenkins:"
sudo systemctl is-active jenkins || true

echo ""
echo "Docker:"
sudo docker --version

echo ""
echo "Terraform:"
terraform version

echo ""
echo "kubectl:"
kubectl version --client

echo ""
echo "AWS CLI:"
aws --version

echo ""
echo "Trivy:"
trivy --version

echo ""
echo "SonarQube:"
sudo docker ps --filter name=sonarqube

echo ""
echo "=========================================="
echo " IMPORTANT"
echo "=========================================="
echo ""
echo "Jenkins:  http://YOUR_EC2_PUBLIC_IP:8080"
echo "SonarQube: http://YOUR_EC2_PUBLIC_IP:9000"
echo ""
echo "Log out and log back in for Docker group"
echo "permissions to take effect."
echo ""
echo "=========================================="
