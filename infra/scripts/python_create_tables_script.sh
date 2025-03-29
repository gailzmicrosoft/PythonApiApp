#!/bin/bash
echo "started the script"

# Variables
baseUrl="$1"
resourceGroup="$2"
key_vault_name="$3"
postgres_server_name="$4"
requirementFile="requirements.txt"
requirementFileUrl=${baseUrl}"infra/scripts/data_scripts/requirements_create_tables.txt"

echo "Script Started"

# Get the public IP address of the machine running the script
publicIp=$(curl -s https://api.ipify.org)

# Use Azure CLI to add the public IP to the PostgreSQL firewall rule
az postgres flexible-server firewall-rule create --resource-group $resourceGroup --name $postgres_server_name --rule-name "AllowScriptIp" --start-ip-address "$publicIp" --end-ip-address "$publicIp"

curl --output "create_psql_tables.py" ${baseUrl}"infra/scripts/data_scripts/create_psql_tables.py"

# Download the requirement file
curl --output "$requirementFile" "$requirementFileUrl"

echo "Download completed"

# Install the required packages
pip install --no-cache-dir -r requirements.txt

# Execute the Python script with the key_vault_name parameter
python create_psql_tables.py --key-vault-name "$key_vault_name"