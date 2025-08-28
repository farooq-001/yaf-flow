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
version: "3.8"

services:
  yaf:
    image: cmusei/yaf:latest
    container_name: yaf
    cap_add:
      - NET_ADMIN
    network_mode: host
    command: >
      --in $SpanPort"
      --live pcap
      --ipfix udp
      --out 127.0.0.1
      --silk
      --verbose
      --ipfix-port=19001
      --applabel
      --max-payload 2048
      --plugin-name=/netsa/lib/yaf/dpacketplugin.so
    restart: unless-stopped

  ####### IPFIX/NetFlow Filebeat ######
  netflow:
    image: docker.elastic.co/beats/filebeat:7.17.27
    container_name: ipfix
    network_mode: host
    volumes:
      - /root/docker/yaf-flow/network-flow.yaml:/usr/share/filebeat/filebeat.yml
      - /root/docker/yaf-flow/registry:/opt/sensor/conf/etc/registry
    environment:
      - BEAT_PATH=/usr/share/filebeat
    user: root
    restart: always

EOF

# Notify the user that the script has completed
echo "Docker Compose configuration has been created in /root/docker/yaf-flow/docker-compose.yml"

# Navigate to the directory and start the services
cd /root/docker/yaf-flow/ || { echo "Error: Failed to navigate to /root/docker/yaf-flow/."; exit 1; }
docker-compose up -d || { echo "Error: Failed to start Docker Compose services."; exit 1; }
docker-compose logs

# Create a log file to indicate the script has been run
echo "Installation completed successfully on $(date)." > "$log_file"
