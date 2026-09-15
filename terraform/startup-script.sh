#!/bin/bash
set -e

# Install Docker
apt-get update
apt-get install -y ca-certificates curl gnupg git
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Clone the repo and bring the stack up
cd /opt
git clone ${repo_url} ci-teaching-kit
cd ci-teaching-kit
docker compose up -d --build

# Note: this brings the stack up automatically on VM creation. Nexus and the
# Jenkins job still need one-time manual configuration (deployer user/role in
# Nexus, creating the Jenkins pipeline job) — see the README for those steps,
# they're account/state setup, not something a startup script can do safely.
