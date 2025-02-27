## PostgreSQL and Python Scripts  
This folder contains PostgreSQL and Python Scripts to set up database, create users, grant permissions, create tables, and populate tables with prepared sample data. 

#### Order of Execution

(1) Create Azure PostgreSQL Server 

(2) Create Database 

(3) Create Tables (`create-tables.sql`)

(4) Upload sample data to tables using Python Scripts in folder **data_prep_python**: 

Change directory to **data_prep_python**, run below Python scripts: 

- run `populate-table-products.py` or `populate-table-products-from-xlsx.py` 
- run `populate-table-customer.py` or `populate-table-customers-from-xslx.py` 
- run `generate-orders.py` 

Review the python scripts for instructions and configurations. 
