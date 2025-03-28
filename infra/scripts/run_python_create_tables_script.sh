#!/bin/bash
echo "started the script"


# Variables

baseUrl="$1"
resourceGroup="$2"
key_vault_name="$3"
postgres_server_name="$4"
host_name="$5"
database_name="$6"
admin_principal_name="$7"
identity_name="$8"  # managed identity user name. Wil use this to connect to the postgres server 
requirementFile="requirements.txt"
requirementFileUrl=${baseUrl}"infra/scripts/data_scripts/requirements_create_tables.txt"

echo "Script Started"

# Get the public IP address of the machine running the script
publicIp=$(curl -s https://api.ipify.org)

# Use Azure CLI to add the public IP to the PostgreSQL firewall rule
az postgres flexible-server firewall-rule create --resource-group $resourceGroup --name $postgres_server_name --rule-name "AllowScriptIp" --start-ip-address "$publicIp" --end-ip-address "$publicIp"

curl --output "run_psql_create_tables_script.py" ${baseUrl}"scripts/data_scripts/run_psql_create_tables_script.py"

# Download the requirement file
curl --output "$requirementFile" "$requirementFileUrl"

echo "Download completed"

# Replace place_holder values in the script with actual values
sed -i "s/key_vault_name_place_holder/${key_vault_name}/g" "run_psql_create_tables_script.py"
sed -i "s/host_name_place_holder/${host_name}/g" "run_psql_create_tables_script.py"
sed -i "s/database_name_place_holder/${database_name}/g" "run_psql_create_tables_script.py"
sed -i "s/admin_principal_name_place_holder/${admin_principal_name}/g" "run_psql_create_tables_script.py"
sed -i "s/identity_name_place_holder/${identity_name}/g" "run_psql_create_tables_script.py"

# Install the required packages
pip install --no-cache-dir -r requirements.txt

# execute python code
python run_psql_create_tables_script.py


