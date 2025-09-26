###########################################
# Filebeat Agent Bootstrap Script (Windows)
# Installs Filebeat, configures modules,
# runs as Windows Service
###########################################

$ELK_HOST = "<ELK_SERVER_IP>"    # CHANGE THIS
$ELK_PORT = "5044"               # CHANGE IF DIFFERENT

Write-Output "[*] Downloading Filebeat..."
Invoke-WebRequest -Uri https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.12.0-windows-x86_64.zip -OutFile filebeat.zip

Expand-Archive .\filebeat.zip -DestinationPath "C:\Program Files" -Force
Rename-Item "C:\Program Files\filebeat-8.12.0-windows-x86_64" "C:\Program Files\Filebeat"

Write-Output "[*] Configuring Filebeat output..."
$ConfigPath = "C:\Program Files\Filebeat\filebeat.yml"

# Backup old config
if (Test-Path "$ConfigPath") {
    Copy-Item $ConfigPath "$ConfigPath.bak" -Force
}

@"
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - C:\Windows\System32\winevt\Logs\Security.evtx
      - C:\Windows\System32\winevt\Logs\System.evtx
      - C:\Windows\System32\winevt\Logs\Application.evtx

filebeat.config.modules:
  path: \${path.config}\modules.d\*.yml
  reload.enabled: true

output.logstash:
  hosts: ["$ELK_HOST:$ELK_PORT"]

processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~
"@ | Out-File -FilePath $ConfigPath -Encoding ascii

Write-Output "[*] Installing Filebeat as service..."
cd "C:\Program Files\Filebeat"
.\install-service-filebeat.ps1

Write-Output "[*] Starting Filebeat service..."
Start-Service filebeat

Write-Output "✅ Filebeat agent installed and running on Windows"
Write-Output "👉 Logs are being shipped to Logstash at $ELK_HOST:$ELK_PORT"
