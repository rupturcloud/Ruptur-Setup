#!/usr/bin/env bash
ruptur_prepare_system() {
    local command_name package
    local -a missing=()
    command -v apt-get >/dev/null || { ruptur_error 'Instalação suportada em Debian/Ubuntu com apt-get'; return 1; }
    while read -r command_name package; do
        command -v "$command_name" >/dev/null || missing+=("$package")
    done <<'PACKAGES'
sudo sudo
curl curl
tar tar
jq jq
dialog dialog
htpasswd apache2-utils
git git
python3 python3
openssl openssl
PACKAGES
    ((${#missing[@]})) || return 0
    apt-get update && apt-get install -y ca-certificates "${missing[@]}"
}
