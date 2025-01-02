#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root."
  exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  echo "Error: Docker is not installed. Please install Docker first."
  exit 1
fi

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
  echo "Error: Docker Compose is not installed. Please install Docker Compose first."
  exit 1
fi

# Check docker-compose version
required_version="1.29.0"
current_version=$(docker-compose --version | awk '{print $3}' | sed 's/,//')
if [[ $(printf '%s\n' "$required_version" "$current_version" | sort -V | head -n1) != "$required_version" ]]; then
  echo "Error: Docker Compose version must be $required_version or higher. Current version: $current_version."
  exit 1
fi

# Check if the script has already been run
log_file="/root/docker/yaf-flow/.docker-compose-install.log"
if [ -f "$log_file" ]; then
  echo "This script has already been run. Installation details are in $log_file."
  exit 0
fi

# Create the required directory
mkdir -p /root/docker/yaf-flow || { echo "Error: Failed to create directory /root/docker/yaf-flow."; exit 1; }

# Get the SpanPort value
if [ -z "$SPAN_PORT" ]; then
  echo "Error: SPAN_PORT environment variable not set. Please provide it before running the script."
  exit 1
else
  SpanPort="$SPAN_PORT"
  echo "Using SpanPort from environment variable: $SpanPort"
fi

# Create the docker-compose.yml file
cat <<EOF > /root/docker/yaf-flow/docker-compose.yml
version: '3.8'

services:
  yaf:
    image: cmusei/yaf:latest
    container_name: yaf
    cap_add:
      - NET_ADMIN
    network_mode: host
    command: >
      --in "$SpanPort"
      --live pcap
      --ipfix udp
      --out 172.17.0.1
      --silk
      --verbose
      --ipfix-port=19001
      --applabel
      --max-payload 2048
      --plugin-name=/netsa/lib/yaf/dpacketplugin.so
    restart: unless-stopped
EOF

# Notify the user that the script has completed
echo "Docker Compose configuration has been created in /root/docker/yaf-flow/docker-compose.yml"

# Navigate to the directory and start the services
cd /root/docker/yaf-flow/ || { echo "Error: Failed to navigate to /root/docker/yaf-flow/."; exit 1; }
docker-compose up -d || { echo "Error: Failed to start Docker Compose services."; exit 1; }
docker-compose logs

# Create a log file to indicate the script has been run
echo "Installation completed successfully on $(date)." > "$log_file"
