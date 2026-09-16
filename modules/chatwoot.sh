#!/usr/bin/env bash
# Identificadores de bancos, volumes e serviços preservam instalações existentes.

ferramenta_chatwoot() {

## Verifica os recursos
recursos 2 2 && continue || return

## Limpa o terminal
clear

## Ativa a função dados para pegar os dados da vps
dados

## Mostra o nome da aplicação
nome_chatwoot

## Mostra mensagem para preencher informações
preencha_as_info

## Inicia um Loop até os dados estarem certos
while true; do

    ruptur_chatwoot_inputs || return 1

    ## Verifica se a porta é 465, se sim deixa o ssl true, se não, deixa false
    if [ "$porta_smtp_chatwoot" -eq 465 ]; then
     sobre_ssl=true
    else
     sobre_ssl=false
    fi

    ## Limpa o terminal
    clear

    ## Mostra o nome da aplicação
    nome_chatwoot

    ## Mostra mensagem para verificar as informações
    conferindo_as_info

    ## Informação sobre URL
    echo -e "\e[33mDominio do ${CHAT_BRAND_NAME}:\e[97m $url_chatwoot\e[0m"
    echo ""

    ## Informação sobre Nome da Empresa
    echo -e "\e[33mNome da Empresa:\e[97m $nome_empresa_chatwoot\e[0m"
    echo ""

    ## Informação sobre Email de SMTP
    echo -e "\e[33mEmail do SMTP:\e[97m $email_admin_chatwoot\e[0m"
    echo ""

    ## Informação sobre Usuario do SMTP
    echo -e "\e[33mUser do SMTP:\e[97m $user_smtp_chatwoot\e[0m"
    echo ""

    ## Informação sobre Senha de SMTP
    echo "Senha SMTP: [oculta]"
    echo ""

    ## Informação sobre Host SMTP
    echo -e "\e[33mHost SMTP:\e[97m $smtp_email_chatwoot\e[0m"
    echo ""

    ## Informação sobre Porta SMTP
    echo -e "\e[33mPorta SMTP:\e[97m $porta_smtp_chatwoot\e[0m"
    echo ""
    echo ""

    ## Pergunta se as respostas estão corretas
    read -p "As respostas estão corretas? (Y/N): " confirmacao
    if [ "$confirmacao" = "Y" ] || [ "$confirmacao" = "y" ]; then

        ## Digitou Y para confirmar que as informações estão corretas

        ## Limpar o terminal
        clear

        ## Mostrar mensagem de Instalando
        instalando_msg

        ## Sai do Loop
        break
    else

        ## Digitou N para dizer que as informações não estão corretas.

        ## Limpar o terminal
        clear

        ## Mostra o nome da ferramenta
        nome_chatwoot

        ## Mostra mensagem para preencher informações
        preencha_as_info

    ## Volta para o inicio do loop com as perguntas
    fi
done


## Mensagem de Passo
echo -e "\e[97m• INICIANDO A INSTALAÇÃO DO ${CHAT_BRAND_NAME} \e[33m[1/6]\e[0m"
echo ""
sleep 1

telemetria Chatwoot iniciado

## Ativa a função dados para pegar os dados da vps
dados

## Mensagem de Passo
echo -e "\e[97m• VERIFICANDO/INSTALANDO PGVECTOR \e[33m[2/6]\e[0m"
echo ""
sleep 1

## Aqui vamos fazer uma verificação se já existe Postgres e redis instalado
## Se tiver ele vai criar um banco de dados no postgres ou perguntar se deseja apagar o que já existe e criar outro

## Verifica container postgres e cria banco no postgres
verificar_container_pgvector
if [ $? -eq 0 ]; then
    echo "1/3 - [ OK ] - PgVector já instalado"
    pegar_senha_pgvector > /dev/null 2>&1
    echo "2/3 - [ OK ] - Copiando senha do PgVector"
    criar_banco_pgvector_da_stack "chatwoot${1:+_$1}"
    echo "3/3 - [ OK ] - Criando banco de dados"
    echo ""
else
    ferramenta_pgvector
    pegar_senha_pgvector > /dev/null 2>&1
    criar_banco_pgvector_da_stack "chatwoot${1:+_$1}"
fi

## Mensagem de Passo
echo -e "\e[97m• INSTALANDO ${CHAT_BRAND_NAME} \e[33m[3/6]\e[0m"
echo ""
sleep 1

## Neste passo vamos estar criando a Stack yaml do Chatwoot na pasta /root/
## Isso possibilitará que o usuario consiga edita-lo posteriormente

## Depois vamos instalar o Chatwoot e verificar se esta tudo certo.

## Criando key aleatória
encryption_key=$(openssl rand -hex 64)

## Criando a stack chatwoot.yaml
ruptur_chatwoot_render standard "chatwoot${1:+_$1}.yaml" "${1:-}" || return 1
if [ $? -eq 0 ]; then
    echo "1/10 - [ OK ] - Criando Stack"
else
    echo "1/10 - [ OFF ] - Criando Stack"
    echo "Não foi possivel criar a stack do ${CHAT_BRAND_NAME}"
fi
STACK_NAME="chatwoot${1:+_$1}"
stack_editavel #> /dev/null 2>&1

#docker stack deploy --prune --resolve-image always -c chatwoot.yaml chatwoot > /dev/null 2>&1
#if [ $? -eq 0 ]; then
#    echo "2/2 - [ OK ] - Deploy Stack"
#else
#    echo "2/2 - [ OFF ] - Deploy Stack"
#    echo "Não foi possivel subir a stack do ${CHAT_BRAND_NAME}"
#fi

## Mensagem de Passo
echo -e "\e[97m• VERIFICANDO SERVIÇO \e[33m[4/6]\e[0m"
echo ""
sleep 1

## Baixando imagens:
pull redis:latest "$CHATWOOT_IMAGE"

## Usa o serviço wait_chatwoot para verificar se o serviço esta online
wait_stack chatwoot${1:+_$1}_chatwoot${1:+_$1}_redis chatwoot${1:+_$1}_chatwoot${1:+_$1}_app chatwoot${1:+_$1}_chatwoot${1:+_$1}_sidekiq

sleep 30
echo ""
## Mensagem de Passo
echo -e "\e[97m• MIGRANDO BANCO DE DADOS \e[33m[5/6]\e[0m"
echo ""
sleep 7

## Aqui vamos estar migrando o banco de dados usando o comando "bundle exec rails db:chatwoot_prepare"

## Basicamente voce poderia entrar no banco de dados do chatwoot e executar o comando por lá tambem

container_name="chatwoot${1:+_$1}_chatwoot${1:+_$1}_app"

max_wait_time=1200

wait_interval=60

elapsed_time=0

while [ $elapsed_time -lt $max_wait_time ]; do
  CONTAINER_ID=$(docker ps -q --filter "name=$container_name")
  if [ -n "$CONTAINER_ID" ]; then
    break
  fi
  sleep $wait_interval
  elapsed_time=$((elapsed_time + wait_interval))
done

if [ -z "$CONTAINER_ID" ]; then
  echo "O contêiner não foi encontrado após $max_wait_time segundos."
  exit 1
fi

local chat_app_container=$CONTAINER_ID
docker exec "$chat_app_container" bundle exec rails db:chatwoot_prepare > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "1/2 - [ OK ] - Executando no container: bundle exec rails db:chatwoot_prepare"
else
    echo "1/2 - [ OFF ] - Executando no container: bundle exec rails db:chatwoot_prepare"
    echo "Não foi possivel migrar o banco de dados"
    return 1
fi

# Nome base do container (pode variar, por isso usamos grep para achar)
pg_container_name="pgvector_pgvector"

# Tempo máximo de espera (em segundos)
max_wait_time=1200
wait_interval=60
elapsed_time=0

# Aguarda até o container aparecer
while [ $elapsed_time -lt $max_wait_time ]; do
  PG_CONTAINER_ID=$(docker ps -q --filter "name=$pg_container_name")
  if [ -n "$PG_CONTAINER_ID" ]; then
    break
  fi
  sleep $wait_interval
  elapsed_time=$((elapsed_time + wait_interval))
done

if [ -z "$PG_CONTAINER_ID" ]; then
  echo "O contêiner do PostgreSQL não foi encontrado após $max_wait_time segundos."
  exit 1
fi

# Executa os comandos SQL dentro do container
docker exec -i "$PG_CONTAINER_ID" psql -v ON_ERROR_STOP=1 -U postgres -v "chat_database=chatwoot${1:+_$1}" <<'SQL' > /dev/null 2>&1
ALTER SYSTEM SET timezone = 'UTC';
SET timezone = 'UTC';
ALTER DATABASE :"chat_database" SET timezone TO 'UTC';
SHOW timezone;
SQL

if [ $? -eq 0 ]; then
    echo "2/2 - [ OK ] - Executando no container: timezone configurado para UTC"
else
    echo "2/2 - [ OFF ] - Falha ao configurar timezone no PostgreSQL"
    echo "Verifique se o banco de dados e o usuário 'postgres' estão acessíveis."
fi

echo ""
## Mensagem de Passo
echo -e "\e[97m• ATIVANDO FUNÇÕES DO SUPER ADMIN \e[33m[6/6]\e[0m"
echo ""
sleep 1

##  Aqui vamos alterar um dado no postgres para liberar algumas funções ocultas no painel de super admin
wait_for_pgvector

docker exec -i "$CONTAINER_ID" psql -v ON_ERROR_STOP=1 -U postgres -d "chatwoot${1:+_$1}" <<'EOF' > /dev/null 2>&1
update installation_configs set locked = false;
\q
EOF
if [ $? -eq 0 ]; then
    echo "1/1 - [ OK ] - Desbloqueando tabela installation_configs no pgvector"
else
    echo "1/1 - [ OFF ] - Desbloqueando tabela installation_configs no pgvector"
    echo "Não foi possivel liberar as funções do super_admin"
    return 1
fi

echo ""

telemetria Chatwoot finalizado

ruptur_chatwoot_brand "$chat_app_container" || return 1

## Salvando informações da instalação dentro de /dados_vps/
cd dados_vps

cat > dados_chatwoot${1:+_$1} <<EOL
[ $nome_empresa_chatwoot ]

Dominio do Chatwoot: https://$url_chatwoot

Usuario: Precisa criar dentro do Chatwoot

Senha: Precisa criar dentro do Chatwoot
EOL

cd
cd

## Espera 30 segundos
wait_30_sec

## Mensagem de finalizado
instalado_msg

## Mensagem de Guarde os Dados
guarde_os_dados_msg

## Dados da Aplicação:
echo -e "\e[32m[ ${CHAT_BRAND_NAME} ]\e[0m"
echo ""

echo -e "\e[97mDominio:\e[33m https://$url_chatwoot\e[0m"
echo ""

echo -e "\e[97mUsuario:\e[33m Precisa criar dentro do ${CHAT_BRAND_NAME}\e[0m"
echo ""

echo -e "\e[97mSenha:\e[33m Precisa criar dentro do ${CHAT_BRAND_NAME}\e[0m"

## Creditos do instalador
creditos_msg

## Pergunta se deseja instalar outra aplicação
requisitar_outra_instalacao
}

ferramenta_chatwoot_nestor() {

## Verifica os recursos
recursos 2 2 && continue || return

## Limpa o terminal
clear

## Ativa a função dados para pegar os dados da vps
dados

## Mostra o nome da aplicação
nome_chatwoot_nestor

## Mostra mensagem para preencher informações
preencha_as_info

## Inicia um Loop até os dados estarem certos
while true; do

    ruptur_chatwoot_inputs || return 1

    ## Verifica se a porta é 465, se sim deixa o ssl true, se não, deixa false
    if [ "$porta_smtp_chatwoot" -eq 465 ]; then
     sobre_ssl=true
    else
     sobre_ssl=false
    fi

    ## Limpa o terminal
    clear

    ## Mostra o nome da aplicação
    nome_chatwoot_nestor

    ## Mostra mensagem para verificar as informações
    conferindo_as_info

    ## Informação sobre URL
    echo -e "\e[33mDominio do ${CHAT_BRAND_NAME}:\e[97m $url_chatwoot\e[0m"
    echo ""

    ## Informação sobre Nome da Empresa
    echo -e "\e[33mNome da Empresa:\e[97m $nome_empresa_chatwoot\e[0m"
    echo ""

    ## Informação sobre Email de SMTP
    echo -e "\e[33mEmail do SMTP:\e[97m $email_admin_chatwoot\e[0m"
    echo ""

    ## Informação sobre Usuario do SMTP
    echo -e "\e[33mUser do SMTP:\e[97m $user_smtp_chatwoot\e[0m"
    echo ""

    ## Informação sobre Senha de SMTP
    echo "Senha SMTP: [oculta]"
    echo ""

    ## Informação sobre Host SMTP
    echo -e "\e[33mHost SMTP:\e[97m $smtp_email_chatwoot\e[0m"
    echo ""

    ## Informação sobre Porta SMTP
    echo -e "\e[33mPorta SMTP:\e[97m $porta_smtp_chatwoot\e[0m"
    echo ""
    echo ""

    ## Pergunta se as respostas estão corretas
    read -p "As respostas estão corretas? (Y/N): " confirmacao
    if [ "$confirmacao" = "Y" ] || [ "$confirmacao" = "y" ]; then

        ## Digitou Y para confirmar que as informações estão corretas

        ## Limpar o terminal
        clear

        ## Mostrar mensagem de Instalando
        instalando_msg

        ## Sai do Loop
        break
    else

        ## Digitou N para dizer que as informações não estão corretas.

        ## Limpar o terminal
        clear

        ## Mostra o nome da ferramenta
        nome_chatwoot_nestor

        ## Mostra mensagem para preencher informações
        preencha_as_info

    ## Volta para o inicio do loop com as perguntas
    fi
done


## Mensagem de Passo
echo -e "\e[97m• INICIANDO A INSTALAÇÃO DO ${CHAT_BRAND_NAME} (Mega) \e[33m[1/7]\e[0m"
echo ""
sleep 1

telemetria "Chatwoot Nestor" "iniciado"

## Ativa a função dados para pegar os dados da vps
dados

## Mensagem de Passo
echo -e "\e[97m• VERIFICANDO/INSTALANDO PGVECTOR \e[33m[2/7]\e[0m"
echo ""
sleep 1

## Aqui vamos fazer uma verificação se já existe Postgres e redis instalado
## Se tiver ele vai criar um banco de dados no postgres ou perguntar se deseja apagar o que já existe e criar outro

## Verifica container postgres e cria banco no postgres
verificar_container_pgvector
if [ $? -eq 0 ]; then
    echo "1/3 - [ OK ] - Postgres já instalado"
    pegar_senha_pgvector > /dev/null 2>&1
    echo "2/3 - [ OK ] - Copiando senha do Postgres"
    criar_banco_pgvector_da_stack "chatwoot_nestor${1:+_$1}"
    echo "3/3 - [ OK ] - Criando banco de dados"
    echo ""
else
    ferramenta_pgvector
    pegar_senha_pgvector > /dev/null 2>&1
    criar_banco_pgvector_da_stack "chatwoot_nestor${1:+_$1}"
fi

## Verifica/instala o Redis
verificar_container_redis
if [ $? -eq 0 ]; then
    echo "1/1 - [ OK ] - Redis já instalado"
    echo ""
else
    ferramenta_redis
fi

## Mensagem de Passo
echo -e "\e[97m• INSTALANDO ${CHAT_BRAND_NAME} (Mega) \e[33m[4/7]\e[0m"
echo ""
sleep 1

## Neste passo vamos estar criando a Stack yaml do Chatwoot na pasta /root/
## Isso possibilitará que o usuario consiga edita-lo posteriormente

## Depois vamos instalar o Chatwoot e verificar se esta tudo certo.

## Criando key aleatória
encryption_key=$(openssl rand -hex 64)

## Criando a stack chatwoot_nestor.yaml
ruptur_chatwoot_render mega "chatwoot_nestor${1:+_$1}.yaml" "${1:-}" || return 1
if [ $? -eq 0 ]; then
    echo "1/10 - [ OK ] - Criando Stack"
else
    echo "1/10 - [ OFF ] - Criando Stack"
    echo "Não foi possivel criar a stack do ${CHAT_BRAND_NAME}"
fi
STACK_NAME="chatwoot_nestor${1:+_$1}"
stack_editavel #> /dev/null 2>&1

#docker stack deploy --prune --resolve-image always -c chatwoot_nestor.yaml chatwoot > /dev/null 2>&1
#if [ $? -eq 0 ]; then
#    echo "2/2 - [ OK ] - Deploy Stack"
#else
#    echo "2/2 - [ OFF ] - Deploy Stack"
#    echo "Não foi possivel subir a stack do ${CHAT_BRAND_NAME}"
#fi

## Mensagem de Passo
echo -e "\e[97m• VERIFICANDO SERVIÇO \e[33m[5/7]\e[0m"
echo ""
sleep 1

## Baixando imagens:
pull "$CHATWOOT_MEGA_IMAGE"

## Usa o serviço wait_chatwoot para verificar se o serviço esta online
wait_stack chatwoot_nestor${1:+_$1}_chatwoot_nestor${1:+_$1}_app chatwoot_nestor${1:+_$1}_chatwoot_nestor${1:+_$1}_sidekiq

telemetria "Chatwoot Nestor" "finalizado"
## Mensagem de Passo
echo -e "\e[97m• MIGRANDO BANCO DE DADOS \e[33m[6/7]\e[0m"
echo ""
sleep 1

## Aqui vamos estar migrando o banco de dados usando o comando "bundle exec rails db:chatwoot_prepare"

## Basicamente voce poderia entrar no banco de dados do chatwoot e executar o comando por lá tambem

container_name="chatwoot_nestor${1:+_$1}_chatwoot_nestor${1:+_$1}_app"

max_wait_time=1200

wait_interval=60

elapsed_time=0

while [ $elapsed_time -lt $max_wait_time ]; do
  CONTAINER_ID=$(docker ps -q --filter "name=$container_name")
  if [ -n "$CONTAINER_ID" ]; then
    break
  fi
  sleep $wait_interval
  elapsed_time=$((elapsed_time + wait_interval))
done

if [ -z "$CONTAINER_ID" ]; then
  echo "O contêiner não foi encontrado após $max_wait_time segundos."
  exit 1
fi

local chat_app_container=$CONTAINER_ID
docker exec "$chat_app_container" bundle exec rails db:chatwoot_prepare > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "1/1 - [ OK ] - Executando no container: bundle exec rails db:chatwoot_prepare"
else
    echo "1/1 - [ OFF ] - Executando no container: bundle exec rails db:chatwoot_prepare"
    echo "Não foi possivel migrar o banco de dados"
    return 1
fi

echo ""
## Mensagem de Passo
echo -e "\e[97m• ATIVANDO FUNÇÕES DO SUPER ADMIN \e[33m[7/7]\e[0m"
echo ""
sleep 1

##  Aqui vamos alterar um dado no postgres para liberar algumas funções ocultas no painel de super admin
wait_for_pgvector

CONTAINER_ID_NESTOR=$(docker ps -q --filter "name=pgvector_pgvector")

docker exec -i "$CONTAINER_ID_NESTOR" psql -v ON_ERROR_STOP=1 -U postgres -d "chatwoot_nestor${1:+_$1}" <<'EOF' > /dev/null 2>&1
update installation_configs set locked = false;
\q
EOF
if [ $? -eq 0 ]; then
    echo "1/1 - [ OK ] - Desbloqueando tabela installation_configs no postgres"
else
    echo "1/1 - [ OFF ] - Desbloqueando tabela installation_configs no postgres"
    echo "Não foi possivel liberar as funções do super_admin"
    return 1
fi

echo ""

ruptur_chatwoot_brand "$chat_app_container" || return 1

## Salvando informações da instalação dentro de /dados_vps/
cd dados_vps

cat > dados_chatwoot_nestor${1:+_$1} <<EOL
[ $nome_empresa_chatwoot (Mega) ]

Dominio do Chatwoot: https://$url_chatwoot

Usuario: Precisa criar dentro do Chatwoot

Senha: Precisa criar dentro do Chatwoot
EOL

cd
cd

## Espera 30 segundos
wait_30_sec

## Mensagem de finalizado
instalado_msg

## Mensagem de Guarde os Dados
guarde_os_dados_msg

## Dados da Aplicação:
echo -e "\e[32m[ ${CHAT_BRAND_NAME} (Mega) ]\e[0m"
echo ""

echo -e "\e[97mDominio:\e[33m https://$url_chatwoot\e[0m"
echo ""

echo -e "\e[97mUsuario:\e[33m Precisa criar dentro do ${CHAT_BRAND_NAME}\e[0m"
echo ""

echo -e "\e[97mSenha:\e[33m Precisa criar dentro do ${CHAT_BRAND_NAME}\e[0m"

## Creditos do instalador
creditos_msg

## Pergunta se deseja instalar outra aplicação
requisitar_outra_instalacao
}
