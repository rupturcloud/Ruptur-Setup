#!/usr/bin/env bash
ruptur_chatwoot_inputs() {
    ruptur_prompt url_chatwoot 'Domínio do atendimento' "$CHAT_DOMAIN" || return
    url_chatwoot=${url_chatwoot#https://}; url_chatwoot=${url_chatwoot#http://}; url_chatwoot=${url_chatwoot%/}
    ruptur_prompt nome_empresa_chatwoot 'Marca do atendimento' "$CHAT_BRAND_NAME" || return
    ruptur_prompt email_admin_chatwoot 'E-mail remetente SMTP' "$SMTP_FROM_EMAIL" || return
    ruptur_prompt user_smtp_chatwoot 'Usuário SMTP' "${SMTP_USERNAME:-$email_admin_chatwoot}" || return
    ruptur_prompt senha_email_chatwoot 'Senha SMTP (entrada oculta; Enter mantém configuração)' "${SMTP_PASSWORD:-}" true || return
    ruptur_prompt smtp_email_chatwoot 'Host SMTP' "${SMTP_HOST:-}" || return
    ruptur_prompt porta_smtp_chatwoot 'Porta SMTP' "$SMTP_PORT" || return
    dominio_smtp_chatwoot=${SMTP_DOMAIN:-${email_admin_chatwoot#*@}}
    ruptur_chatwoot_validate
}

ruptur_chatwoot_validate() {
    ruptur_hostname_valid "$url_chatwoot" || { ruptur_error 'Domínio do atendimento inválido'; return 1; }
    ruptur_hostname_valid "$smtp_email_chatwoot" || { ruptur_error 'Informe um host SMTP válido'; return 1; }
    [[ "$email_admin_chatwoot" =~ ^[^[:space:]@]+@[^[:space:]@]+$ ]] || { ruptur_error 'Remetente inválido'; return 1; }
    [[ -n "$senha_email_chatwoot" && -n "$user_smtp_chatwoot" && -n "$nome_empresa_chatwoot" ]] || { ruptur_error 'Informe marca, usuário e senha SMTP'; return 1; }
    [[ "$porta_smtp_chatwoot" =~ ^[0-9]{1,5}$ ]] && ((10#$porta_smtp_chatwoot > 0 && 10#$porta_smtp_chatwoot <= 65535)) || { ruptur_error 'Porta SMTP inválida'; return 1; }
}

ruptur_chatwoot_render() {
    local variant=$1 output=$2 instance=${3:-} INSTANCE_SUFFIX=
    [[ "$variant" == standard || "$variant" == mega ]] || return 1
    [[ -z "$instance" || "$instance" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || { ruptur_error 'Instância inválida'; return 1; }
    [[ "$nome_rede_interna" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || { ruptur_error 'Rede inválida'; return 1; }
    [[ -z "$instance" ]] || INSTANCE_SUFFIX="_$instance"
    ruptur_chatwoot_validate || return
    [[ -n "$senha_pgvector" && -n "$encryption_key" ]] || { ruptur_error 'Informe senha PostgreSQL e chave da aplicação'; return 1; }
    sobre_ssl=false
    [[ "$porta_smtp_chatwoot" != 465 ]] || sobre_ssl=true
    # SSL implícito e STARTTLS são modos distintos.
    local chat_starttls=$SMTP_STARTTLS
    [[ "$sobre_ssl" != true ]] || chat_starttls=false
    ruptur_render "$RUPTUR_ROOT/templates/chatwoot/$variant.yaml.template" "$output"
}

ruptur_chatwoot_preview() {
    local url_chatwoot=$CHAT_DOMAIN nome_empresa_chatwoot=$CHAT_BRAND_NAME
    local email_admin_chatwoot=$SMTP_FROM_EMAIL user_smtp_chatwoot=${SMTP_USERNAME:-$SMTP_FROM_EMAIL}
    local senha_email_chatwoot=${SMTP_PASSWORD:-} smtp_email_chatwoot=${SMTP_HOST:-} porta_smtp_chatwoot=$SMTP_PORT
    local dominio_smtp_chatwoot=${SMTP_DOMAIN:-${SMTP_FROM_EMAIL#*@}} nome_rede_interna=$DOCKER_NETWORK
    local senha_pgvector=${CHAT_POSTGRES_PASSWORD:-} encryption_key=${CHAT_SECRET_KEY:-}
    if [[ -z "$encryption_key" ]]; then encryption_key=$(openssl rand -hex 64) || return; fi
    ruptur_chatwoot_render "$RUPTUR_VARIANT" "$RUPTUR_OUTPUT" "$RUPTUR_INSTANCE" || return
    printf 'Stack gerada sem deploy: %s\n' "$RUPTUR_OUTPUT"
}

# Executa dentro do container selecionado, sem inserir os valores no código Ruby.
ruptur_chatwoot_brand() {
    local container=$1
    docker exec -i -e "RUPTUR_CHAT_BRAND=$nome_empresa_chatwoot" -e "RUPTUR_BRAND_URL=$BASE_URL" \
        -e "RUPTUR_SUPPORT_EMAIL=$SUPPORT_EMAIL" "$container" bundle exec rails runner - \
        < "$RUPTUR_ROOT/templates/chatwoot/branding.rb" || { ruptur_error 'Falha ao aplicar marca do atendimento'; return 1; }
}

ruptur_chatwoot_emails() {
    local variant=${1:-standard} instance=${2:-} stack=chatwoot file container
    [[ -z "$instance" || "$instance" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || return 1
    [[ "$variant" != mega ]] || stack=chatwoot_nestor
    stack+=${instance:+_$instance}
    container=$(docker ps --filter "label=com.docker.swarm.service.name=${stack}_${stack}_app" --format '{{.ID}}' | head -n 1)
    [[ -n "$container" ]] || { ruptur_error "Container local não encontrado para $stack"; return 1; }
    for file in confirmation_instructions password_change reset_password_instructions unlock_instructions; do
        docker exec "$container" sh -c 'test ! -f "$1" || cp -p "$1" "$1.old"' sh "/app/app/views/devise/mailer/$file.html.erb" || return
        docker cp "$RUPTUR_ROOT/Extras/Chatwoot/emails/$file.html.erb" "$container:/app/app/views/devise/mailer/$file.html.erb" || return
    done
    printf 'Templates de e-mail atualizados: %s\n' "$stack"
}
