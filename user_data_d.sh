#!/bin/bash

#var
EFS_VOL="/mnt/efs"
WORDPRESS_VOL="/var/www/html"
DB_HOST="database-1-docker.cfmuwmyegdds.us-east-1.rds.amazonaws.com"
DB_USUARIO="admin"
DB_SENHA="adminadmin"
DB_NOME="banco_de_dados_docker"

#updates e instalações
sudo yum update -y
sudo yum install docker -y
sudo yum install amazon-efs-utils -y

#docker
sudo usermod -aG docker $(whoami)
sudo systemctl start docker
sudo systemctl enable docker

#EFS
sudo mkdir -p $EFS_VOL
if ! mountpoint -q $EFS_VOL; then
  echo "Montando volume EFS..."
  sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 10.1.4.51:/ $EFS_VOL
else
  echo "Não foi possível montar o volume EFS. Verifique o que pode ser a causa e tente novamente."
fi

#Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /bin/docker-compose
chmod +x /bin/docker-compose

cat <<EOL > /home/ec2-user/docker-compose.yaml
version: '3.8'
services:
  wordpress:
    image: wordpress:latest
    volumes:
      - $EFS_VOL$WORDPRESS_VOL:/$WORDPRESS_VOL
    ports:
      - 80:80
    environment:
      WORDPRESS_DB_HOST: $DB_HOST
      WORDPRESS_DB_USUARIO: $DB_USER
      WORDPRESS_DB_SENHA: $DB_PASSWORD
      WORDPRESS_DB_NOME: $DB_NAME
EOL

#wordpress
docker-compose -f /home/ec2-user/docker-compose.yaml up -d