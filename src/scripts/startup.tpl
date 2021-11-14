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

docker run \
    --rm \
    -d \
    --name nginx-basic-auth-proxy \
    --network airbyte_default \
    -p 80:8080 \
    -p 8090:8090 \
    -e PROXY_PASS=http://webapp:80/ \
    -e BASIC_AUTH_USERNAME=${NGINX_USERNAME} \
    -e BASIC_AUTH_PASSWORD=${NGINX_PASSWORD} \
    -e PORT=8080 \
    quay.io/dtan4/nginx-basic-auth-proxy
