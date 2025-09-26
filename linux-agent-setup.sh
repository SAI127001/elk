#!/bin/bash
#
# Ubuntu Filebeat Agent Setup (with Kibana Fix for Dashboards)
# Installs Filebeat, enables useful modules & filesets,
# loads dashboards into Kibana, and runs as a systemd service
#
# Usage: chmod +x linux-agent-setup.sh && ./linux-agent-setup.sh
#

ELK_HOST="172.16.10.97"   # <-- CHANGE THIS TO YOUR ELK SERVER (Elasticsearch + Kibana + Logstash)
ELK_PORT="5044"           # <-- Logstash Beats input port

set -e

echo "[*] Updating system APT repos..."
apt-get update -y

echo "[*] Downloading and installing Filebeat 8.12.0..."
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.12.0-amd64.deb
dpkg -i filebeat-8.12.0-amd64.deb

echo "[*] Backing up default config..."
cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.bak

echo "[*] Writing Filebeat config (Logstash output)..."
tee /etc/filebeat/filebeat.yml > /dev/null <<EOF
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

# Point Filebeat to Kibana for dashboards
setup.kibana:
  host: "http://${ELK_HOST}:5601"

output.logstash:
  hosts: ["${ELK_HOST}:${ELK_PORT}"]

processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~
  - add_docker_metadata: ~
  - add_kubernetes_metadata: ~
EOF

echo "[*] Enabling important modules (system, apache, nginx, auditd)..."
filebeat modules enable system apache nginx auditd

echo "[*] Enabling default filesets for modules..."
# System
sed -i 's/enabled: false/enabled: true/' /etc/filebeat/modules.d/system.yml || true
# Apache
sed -i 's/enabled: false/enabled: true/' /etc/filebeat/modules.d/apache.yml || true
# Nginx
sed -i 's/enabled: false/enabled: true/' /etc/filebeat/modules.d/nginx.yml || true
# Auditd
sed -i 's/enabled: false/enabled: true/' /etc/filebeat/modules.d/auditd.yml || true

echo "[*] Temporarily switching to Elasticsearch to load dashboards..."
# Backup logstash config
cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.logstash

# Minimal ES config (with Kibana)
tee /etc/filebeat/filebeat.yml > /dev/null <<EOF
setup.kibana:
  host: "http://${ELK_HOST}:5601"

output.elasticsearch:
  hosts: ["http://${ELK_HOST}:9200"]
EOF

# Setup dashboards
filebeat setup --dashboards --index-management --pipelines

# Restore Logstash config
mv /etc/filebeat/filebeat.yml.logstash /etc/filebeat/filebeat.yml

echo "[*] Enabling and starting Filebeat in systemd..."
systemctl enable filebeat
systemctl restart filebeat

echo "✅ Filebeat agent installed and running on Ubuntu."
echo "👉 Logs are being shipped to Logstash at ${ELK_HOST}:${ELK_PORT}."
echo "📊 Dashboards should now be visible in Kibana (http://${ELK_HOST}:5601)."
