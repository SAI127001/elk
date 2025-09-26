#!/bin/bash
#
# Ubuntu Filebeat Agent Setup (with Dashboard Fix)
# Installs Filebeat, enables useful modules & filesets, loads dashboards, and runs as systemd service
#
# Usage: chmod +x ubuntu-filebeat-agent.sh && ./ubuntu-filebeat-agent.sh
#

ELK_HOST="172.16.10.97"   # <-- CHANGE THIS TO YOUR ELK SERVER (Elasticsearch + Logstash)
ELK_PORT="5044"           # <-- Logstash Beats input port

set -e

echo "[*] Updating system APT repos..."
sudo apt-get update -y

echo "[*] Downloading and installing Filebeat 8.12.0..."
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.12.0-amd64.deb
sudo dpkg -i filebeat-8.12.0-amd64.deb

echo "[*] Backing up default config..."
sudo cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.bak

echo "[*] Writing Filebeat config (Logstash output)..."
sudo tee /etc/filebeat/filebeat.yml > /dev/null <<EOF
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/*.log

filebeat.config.modules:
  path: \${path.config}/modules.d/*.yml
  reload.enabled: true

setup.template.settings:
  index.number_of_shards: 1

output.logstash:
  hosts: ["${ELK_HOST}:${ELK_PORT}"]

processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~
  - add_docker_metadata: ~
  - add_kubernetes_metadata: ~
EOF

echo "[*] Enabling important modules (system, apache, nginx, auditd)..."
sudo filebeat modules enable system apache nginx auditd

echo "[*] Enabling default filesets for modules..."

# Enable filesets for system module
sudo sed -i 's/enabled: false/enabled: true/' /etc/filebeat/modules.d/system.yml || true

# Enable filesets for apache module
sudo sed -i 's/enabled: false/enabled: true/' /etc/filebeat/modules.d/apache.yml || true

# Enable filesets for nginx module
sudo sed -i 's/enabled: false/enabled: true/' /etc/filebeat/modules.d/nginx.yml || true

# Enable filesets for auditd module
sudo sed -i 's/enabled: false/enabled: true/' /etc/filebeat/modules.d/auditd.yml || true

echo "[*] Temporarily switching to Elasticsearch to load dashboards..."
# Backup logstash config
sudo cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.logstash

# Minimal ES config
sudo tee /etc/filebeat/filebeat.yml > /dev/null <<EOF
output.elasticsearch:
  hosts: ["http://${ELK_HOST}:9200"]
EOF

# Setup dashboards
sudo filebeat setup --dashboards

# Restore Logstash config
sudo mv /etc/filebeat/filebeat.yml.logstash /etc/filebeat/filebeat.yml

echo "[*] Enabling and starting Filebeat in systemd..."
sudo systemctl enable filebeat
sudo systemctl restart filebeat

echo "✅ Filebeat agent installed and running on Ubuntu."
echo "👉 Logs are being shipped to Logstash at ${ELK_HOST}:${ELK_PORT}."
echo "📊 Dashboards successfully imported into Kibana (http://${ELK_HOST}:5601)."
