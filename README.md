# Projeto AWS e Docker

## Objetivos

- Instalação e configuração do DOCKER ou CONTAINERD no host EC2;
- Efetuar Deploy de uma aplicação Wordpress com: container de aplicação RDS database Mysql;
- Configuração da utilização do serviço EFS AWS para estáticos do container de aplicação Wordpress.
- Configuração do serviço de Load Balancer AWS para a aplicação Wordpress.

---

# Execução

- Criar uma VPC com duas sub-nets, cada uma em uma zona de disponibilidade diferentes.
- Criar uma Tabela de Rotas para permitir o tráfego pelo gateway de internet e associar as duas sub-nets a ela.
- Criar duas Instâncias EC2, cada uma para uma zona de disponibilidade, ambas com os seguintes grupos de segurança:
    - Grupo de segurança Load Balancer
    
    | TIPO | PROTOCOLO | PORTA | ORIGEM |
    | --- | --- | --- | --- |
    | HTTP | TCP | 80 | 0.0.0.0/0 |
    - Grupo de segurança Instância
    
    | TIPO | PROTOCOLO | PORTA | ORIGEM |
    | --- | --- | --- | --- |
    | HTTP | TPC | 80 | Grupo de segurança Load Balancer |
    | SSH | TCP | 22 | [IP do usuário] |
    | HTTP | TCP | 80 | 0.0.0.0/0 |
    - Grupo de segurança SQL
    
    | TIPO | PROTOCOLO | PORTA | ORIGEM |
    | --- | --- | --- | --- |
    | MYSQL/Aurora | TCP | 3306 | Grupo de segurança Instância |
    - Grupo de segurança EFS
    
    | TIPO | PROTOCOLO | PORTA | ORIGEM |
    | --- | --- | --- | --- |
    | NFS | TCP | 2049 | Grupo de segurança Instância |

- Para as instalações e montagens das aplicações necessárias (docker, docker-compose, efs, container-wordpress), utilizar o seguinte modelo de script na área de User Data dentro de Detalhes Avançados (durante a criação da instância), não esquecendo de mudar as variáveis e o mount do efs sempre que necessário (diferentes zonas de disponibilidade, diferentes batabases).

```
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
  sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 10.1.0.86:/ $EFS_VOL
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
```

- Criar o **Load Balancer** selecionando o esquema “Voltado para internet”, selecionar a VPC e as sub-nets, e selecionar o grupo de segurança Load Balancer.
- Criar o **EFS** selecionando a VPC.
- Criar o **RDS** selecionando o banco MySQL no modelo de nível gratuito, escolher as credenciais, selecionar a VPC e o grupo de segurança SQL, deixar a zona de disponibilidade sem preferência.
- Criar o **Grupo de Destino** para instâncias, com protocolo HTTP e porta 8080, tipo de endereço IP IPv4, escolher a VPC criada, e realizar o registro das instâncias.
- Criar os **Modelos de Execução** com as mesmas configurações das instâncias.
- Criar o **Autoscaling** e selecionar o Modelo de Execução de acordo com cada zona de disponibilidade, em versão selecionar Latest, selecionar o Load Balancer já criado.