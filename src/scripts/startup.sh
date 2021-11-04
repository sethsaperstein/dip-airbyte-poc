#!/bin/bash

sudo yum update -y
sudo yum install -y docker
sudo service docker start
sudo usermod -a -G docker $USER

sudo wget https://github.com/docker/compose/releases/download/1.26.2/docker-compose-$(uname -s)-$(uname -m) -O /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version

mkdir airbyte && cd airbyte
wget https://raw.githubusercontent.com/airbytehq/airbyte/master/{.env,docker-compose.yaml}
docker-compose up -d

sudo yum install -y httpd
sudo amazon-linux-extras install -y nginx1
sudo htpasswd -bc /etc/nginx/.htpasswd dip password
sudo cp ../resources/nginx.conf /etc/nginx/nginx.conf
sudo service nginx start
