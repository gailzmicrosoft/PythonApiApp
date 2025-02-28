# Steps to create the solution

1. **Set up your Python project**
   - Create a new folder **src** folder. 
   
     - Set up virtual environment: `python -m venv .venv`
     - Activate the virtual environment (src folder): `\.venv\Scripts\Activate` 
   
   - Create `requirements.txt` in **src** folder. run `pip install -r requirements.txt`: 
   
     #filepath: src/requirments.txt
   
     Flask==2.2.5
     requests==2.31.0
     pandas==1.5.3
     numpy==1.23.5
     SQLAlchemy==1.4.46
     pytest==7.2.0
     Authlib==1.0.0
     jupyter==1.0.0
   
   - Create sub directory under **src**: `src/apiapp` 
   
   - Create your main Python app file: `src/apiapp/app.py` 
   
2. **Write a Dockerfile and .dockerignore**

​	#filepath: /src/Dockerfile, #filepath: /src/.dockerignore 

2. **Create and code app.py and set up SERVER_API_KEY**

​	Create app.py with Security Features: `#filepath: /c:Repos/PythonApiApp/app.py`

​	Set up environment variable in PowerShell: `$Env:SERVER_API_KEY="YourApiKeySample"` 

​	Set up environment variable in windows terminal: `set SERVER_API_KEY=YourApiKeySample`

​	Retrieve the environment variable: `echo $Env:SERVER_API_KEY`

​	Test your app with this command: `python app.py` 

​	Create virtual environment: python / `py -m venv .venv` 

​	Install python libraries: `pip install -r requirements.txt`

​	Run app.py locally "F5" or python / `py app.py` 

​	Test server code from browser: 

​		curl -H "x-api-key:YourApiKeySample" http://localhost:8080/

3. **Build and push the container** 
   - [ ] `docker build -t <your_registry_name>.azurecr.io/pythonapiapp:v1 .`
   - [ ] `docker push <your_registry_name>.azurecr.io/pythonapiapp:v1`

4. **Prepare your Azure Environment** 

```
az login
az account set --subscription "<your_subscription>"

# Create a resource group
az group create --name "<your_rg_name>" --location "<region>"

# Enable the Container Apps feature
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights
```

5. **Create and deploy to Azure Container App**

```
# Create a container environment
az containerapp env create `
    --name "<your_env_name>" `
    --resource-group "<your_rg_name>" `
    --location "<region>"

# Create the Container App
az containerapp create `
    --name "<your_app_name>" `
    --resource-group "<your_rg_name>" `
    --environment "<your_env_name>" `
    --image <your_registry_name>.azurecr.io/pythonapiapp:v1 `
    --target-port 80 `
    --ingress external
```

6. **Test and iterate** 
   - Check logs and endpoint in Azure Portal.
   - Update code, rebuild, and push new container images as needed.