FROM python:3.9-slim

WORKDIR /app

# Copy the requirements.txt file and install dependencies
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Copy the rest of the application code
COPY apiapp /app
#If your app dir will contain more sub dirs use below line instead of the above line
#COPY src/apiapp /app/apiapp

CMD ["python", "/app/app.py"]

#######################################################################################
#
# Buid and run the docker image using below commands in the terminal, project directory 
# which is one level above the src dir
#
# cd src 
#
# docker build -t pythonapiapp .
# docker run -p 8080:8080 pythonapiapp
#
# run the docker image in detached mode using below command: 
# docker run -d -p 8080:8080 pythonapiapp

# To stop the docker container use below command:
# docker ps -a
#
# docker stop <container_id>
# docker rm <container_id>
#
# To remove the docker image use below command: 
# docker rmi pythonapiapp

#######################################################################################
# Command for removing all ocker resources 
#
#Stop all running containers:
# docker stop $(docker ps -q)
#
#Remove all containers:
#docker rm $(docker ps -a -q)
#
#Remove all images:
#docker rmi $(docker images -q)
#
#Remove all volumes (optional)
#docker volume rm $(docker volume ls -q)
#
#Remove all networks (optional)
#docker network rm $(docker network ls -q)
#
#Perform a system prune to clean up any remaining resources (optional):
#docker system prune -a --volumes
#
#
#######################################################################################
# Forcefully remove all containers and images:
# docker rm -f $(docker ps -a -q)
#docker rmi $(docker images -q)

