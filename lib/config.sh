#!/usr/bin/env bash
# Configuração compartilhada; nunca executar o conteúdo de um arquivo .env.
RUPTUR_CONFIG_KEYS='PROJECT_NAME BRAND_NAME BASE_URL SUPPORT_EMAIL SERVER_NAME DOCKER_NETWORK MONITOR_DIR EVOLUTION_V1_PREFIX CHAT_BRAND_NAME CHAT_DOMAIN SMTP_FROM_EMAIL SMTP_USERNAME SMTP_HOST SMTP_PORT SMTP_PASSWORD SMTP_DOMAIN SMTP_AUTHENTICATION SMTP_STARTTLS CHATWOOT_IMAGE CHATWOOT_MEGA_IMAGE CW_ENABLE_ENTERPRISE ENTERPRISE_TOKEN CHATWOOT_HUB_URL GITHUB_ORG GITHUB_REPO GITHUB_REF ASSET_BASE_URL QUEPASA_WORKFLOWS_URL TELEMETRY_ENABLED TELEMETRY_URL PUBLIC_IP_URL COMMUNITY_URL VIDEO_URL DONATION_KEY FORMBRICKS_LICENSE_URL SUPABASE_MCP_PATH'

ruptur_error() { printf 'Erro: %s\n' "$*" >&2; return 1; }
ruptur_known_key() { [[ " $RUPTUR_CONFIG_KEYS " == *" $1 "* ]]; }

ruptur_set() {
    local key=$1 value=$2
    ruptur_known_key "$key" || { ruptur_error "Configuração desconhecida: $key"; return 1; }
    [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || { ruptur_error "Valor multilinha: $key"; return 1; }
    printf -v "$key" '%s' "$value"
}

ruptur_load_env() {
    local file=$1 line key value number=0
    [[ -f "$file" ]] || { ruptur_error "Arquivo não encontrado: $file"; return 1; }
    while IFS= read -r line || [[ -n "$line" ]]; do
        number=$((number + 1)); line=${line%$'\r'}
        [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
        [[ "$line" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]] || { ruptur_error "Formato KEY=value inválido: $file:$number"; return 1; }
        key=${BASH_REMATCH[1]}; value=${BASH_REMATCH[2]}
        ruptur_known_key "$key" || { ruptur_error "Configuração desconhecida: $key"; return 1; }
        if [[ "$value" == \"*\" || "$value" == \'*\' ]]; then value=${value:1:${#value}-2}; fi
        # O ambiente já definido tem prioridade sobre o arquivo.
        if [[ ! -v "$key" ]]; then ruptur_set "$key" "$value" || return; fi
    done < "$file"
}

ruptur_help() {
    cat <<'HELP'
RupturSetup — instalador configurável para Docker Swarm
Uso: bash RupturSetup [opções]
  --config ARQUIVO         Configuração KEY=value (padrão: .env ao lado do script)
  --set CHAVE=VALOR         Sobrescreve uma configuração conhecida
  --domain DOMINIO_OU_URL   URL base da marca
  --brand NOME             Marca do parceiro
  --chat-brand NOME        Marca do atendimento
  --network NOME           Rede Docker padrão para novas instalações
  --smtp-user USUARIO      Usuário SMTP
  --smtp-host HOST         Host SMTP
  --org ORG --repo REPO --ref REF  Origem dos recursos
  --check-config           Valida configuração sem instalar nem mostrar segredos
  --render-chatwoot ARQ    Gera stack sem deploy (requer SMTP_HOST/SMTP_PASSWORD)
  --variant standard|mega  Variante para geração (padrão: mega)
  --instance IDENTIFICADOR Sufixo dos recursos da stack gerada
  --help                  Mostra esta ajuda sem alterar o sistema
Senhas para geração: SMTP_PASSWORD, CHAT_SECRET_KEY e CHAT_POSTGRES_PASSWORD
via ambiente; evite passar segredos em argumentos de linha de comando.
HELP
}

ruptur_config_init() {
    local arg key value config_file="${RUPTUR_CONFIG_FILE:-$RUPTUR_ROOT/.env}" explicit=false
    local -a args=("$@")
    RUPTUR_ACTION=install; RUPTUR_VARIANT=mega; RUPTUR_INSTANCE=; RUPTUR_OUTPUT=
    while (($#)); do
        case "$1" in
            --help|-h) ruptur_help; RUPTUR_ACTION=help; return 0 ;;
            --config) (($# >= 2)) || { ruptur_error 'Falta o arquivo de configuração'; return 1; }; config_file=$2; explicit=true; shift ;;
        esac
        shift
    done
    if [[ -f "$config_file" || "$explicit" == true ]]; then ruptur_load_env "$config_file" || return; fi
    set -- "${args[@]}"
    while (($#)); do
        arg=$1; shift
        case "$arg" in
            --check-config) RUPTUR_ACTION=check; continue ;;
            --config) shift; continue ;;
            --set|--domain|--brand|--chat-brand|--network|--smtp-user|--smtp-host|--org|--repo|--ref|--render-chatwoot|--variant|--instance)
                (($#)) || { ruptur_error "Falta valor para $arg"; return 1; }; value=$1; shift ;;
            *) ruptur_error "Argumento desconhecido: $arg"; return 1 ;;
        esac
        case "$arg" in
            --set) [[ "$value" == *=* ]] || { ruptur_error 'Use --set CHAVE=VALOR'; return 1; }; key=${value%%=*}; value=${value#*=} ;;
            --domain) key=BASE_URL; [[ "$value" == *://* ]] || value="https://$value" ;;
            --brand) key=BRAND_NAME ;;
            --chat-brand) key=CHAT_BRAND_NAME ;;
            --network) key=DOCKER_NETWORK ;;
            --smtp-user) key=SMTP_USERNAME ;;
            --smtp-host) key=SMTP_HOST ;;
            --org) key=GITHUB_ORG ;;
            --repo) key=GITHUB_REPO ;;
            --ref) key=GITHUB_REF ;;
            --render-chatwoot) RUPTUR_ACTION=render; RUPTUR_OUTPUT=$value; continue ;;
            --variant) RUPTUR_VARIANT=$value; continue ;;
            --instance) RUPTUR_INSTANCE=$value; continue ;;
        esac
        ruptur_set "$key" "$value" || return
    done
    : "${PROJECT_NAME:=RupturSetup}" "${BRAND_NAME:=Ruptur}" "${BASE_URL:=https://ruptur.cloud}"
    BASE_URL=${BASE_URL%/}; BASE_DOMAIN=${BASE_URL#*://}
    : "${SUPPORT_EMAIL:=contato@ruptur.cloud}" "${DOCKER_NETWORK:=ruptur-net}" "${SERVER_NAME:=ruptur}"
    : "${MONITOR_DIR:=/opt/monitor-ruptur}" "${EVOLUTION_V1_PREFIX:=evolution_rupturcloud}"
    : "${CHAT_BRAND_NAME:=Ruptur-Chat}" "${CHAT_DOMAIN:=chat.$BASE_DOMAIN}"
    : "${SMTP_FROM_EMAIL:=ruptur.cloud@gmail.com}" "${SMTP_PORT:=587}" "${SMTP_AUTHENTICATION:=login}" "${SMTP_STARTTLS:=true}"
    : "${CHATWOOT_IMAGE:=chatwoot/chatwoot:latest}" "${CHATWOOT_MEGA_IMAGE:=sendingtk/chatwoot:latest}"
    : "${CW_ENABLE_ENTERPRISE:=true}" "${ENTERPRISE_TOKEN:=true}" "${CHATWOOT_HUB_URL:=$BASE_URL/setup#}"
    : "${GITHUB_ORG:=rupturcloud}" "${GITHUB_REPO:=ruptur-setup}" "${GITHUB_REF:=main}"
    : "${ASSET_BASE_URL:=https://raw.githubusercontent.com/$GITHUB_ORG/$GITHUB_REPO/$GITHUB_REF}"
    : "${TELEMETRY_ENABLED:=false}" "${PUBLIC_IP_URL:=https://api.ipify.org}" "${SUPABASE_MCP_PATH:=ruptur-setup}"
    : "${COMMUNITY_URL:=$BASE_URL}" "${VIDEO_URL:=$BASE_URL}" "${FORMBRICKS_LICENSE_URL:=$BASE_URL}"
    ruptur_config_validate
}

ruptur_hostname_valid() {
    [[ "$1" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ && "$1" != *..* && ${#1} -le 253 ]]
}

ruptur_config_validate() {
    local key value
    for key in $RUPTUR_CONFIG_KEYS; do
        value=${!key:-}
        [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || { ruptur_error "Valor multilinha: $key"; return 1; }
    done
    [[ "$BASE_URL" == https://* || "$BASE_URL" == http://* ]] && ruptur_hostname_valid "$BASE_DOMAIN" || { ruptur_error 'BASE_URL deve conter esquema e hostname, sem caminho ou porta'; return 1; }
    for key in DOCKER_NETWORK SERVER_NAME SUPABASE_MCP_PATH GITHUB_ORG GITHUB_REPO EVOLUTION_V1_PREFIX; do
        [[ "${!key}" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || { ruptur_error "Identificador inválido: $key"; return 1; }
    done
    [[ "$MONITOR_DIR" =~ ^/[a-zA-Z0-9_./-]+$ && "$MONITOR_DIR" != / && "$MONITOR_DIR" != *..* ]] || { ruptur_error 'MONITOR_DIR deve ser um diretório absoluto específico, sem espaços'; return 1; }
    [[ "$GITHUB_REF" =~ ^[a-zA-Z0-9][a-zA-Z0-9_./-]*$ && "$GITHUB_REF" != *..* ]] || { ruptur_error 'GITHUB_REF inválido'; return 1; }
    for key in CW_ENABLE_ENTERPRISE SMTP_STARTTLS TELEMETRY_ENABLED; do
        [[ "${!key}" == true || "${!key}" == false ]] || { ruptur_error "$key deve ser true ou false"; return 1; }
    done
    for key in ASSET_BASE_URL QUEPASA_WORKFLOWS_URL TELEMETRY_URL PUBLIC_IP_URL; do
        value=${!key:-}
        [[ -z "$value" || "$value" == https://* ]] || { ruptur_error "$key deve usar HTTPS"; return 1; }
    done
    [[ "$TELEMETRY_ENABLED" != true || -n "${TELEMETRY_URL:-}" ]] || { ruptur_error 'Informe TELEMETRY_URL para habilitar telemetria'; return 1; }
    [[ "$SMTP_PORT" =~ ^[0-9]{1,5}$ ]] && ((10#$SMTP_PORT > 0 && 10#$SMTP_PORT <= 65535)) || { ruptur_error 'Porta SMTP inválida'; return 1; }
    [[ "$RUPTUR_VARIANT" == standard || "$RUPTUR_VARIANT" == mega ]] || { ruptur_error 'Variante inválida'; return 1; }
    [[ -z "$RUPTUR_INSTANCE" || "$RUPTUR_INSTANCE" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || { ruptur_error 'Instância inválida'; return 1; }
}

ruptur_prompt() {
    local destination=$1 label=$2 fallback=${3:-} secret=${4:-false} answer
    if [[ "$secret" == true ]]; then
        IFS= read -r -s -p "$label: " answer || return 1; printf '\n' >&2
    else
        IFS= read -r -p "$label [$fallback]: " answer || return 1
    fi
    printf -v "$destination" '%s' "${answer:-$fallback}"
}

# Adapta os prompts SMTP dos demais instaladores ao mesmo modelo central.
ruptur_smtp_prompt() {
    local kind=$1 destination=$2 label=$3 fallback= secret=false
    case "$kind" in
        from) fallback=$SMTP_FROM_EMAIL ;;
        user) fallback=${SMTP_USERNAME:-${RUPTUR_SMTP_FROM:-$SMTP_FROM_EMAIL}} ;;
        password) fallback=${SMTP_PASSWORD:-}; secret=true ;;
        host) fallback=${SMTP_HOST:-} ;;
        port) fallback=$SMTP_PORT ;;
        *) return 1 ;;
    esac
    ruptur_prompt "$destination" "$label" "$fallback" "$secret" || return
    [[ "$kind" != from ]] || RUPTUR_SMTP_FROM=${!destination}
}
