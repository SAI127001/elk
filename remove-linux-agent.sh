#!/bin/bash

echo "Stopping Filebeat service..."
sudo systemctl stop filebeat
sudo systemctl disable filebeat

echo "Removing Filebeat package (without purging)..."
sudo apt remove filebeat -y

echo "Removing Filebeat logs and data directories..."
sudo rm -rf /var/lib/filebeat
sudo rm -rf /var/log/filebeat

echo "Checking if Filebeat binary still exists..."
if ! command -v filebeat &> /dev/null
then
    echo "Filebeat removed successfully."
else
    echo "Filebeat binary still exists."
fi

echo "Done."
