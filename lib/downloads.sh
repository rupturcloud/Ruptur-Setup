#!/usr/bin/env bash
ruptur_download() {
    local url=$1 destination=$2 temporary
    [[ "$url" == https://* ]] || { ruptur_error 'Download exige HTTPS'; return 1; }
    temporary=$(mktemp "${destination}.XXXXXX") || return
    if curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --connect-timeout 15 --max-time 180 "$url" -o "$temporary"; then
        mv -- "$temporary" "$destination"
    else
        rm -f -- "$temporary"
        ruptur_error "Falha no download: $url"
    fi
}

ruptur_asset() {
    local relative=$1 destination=$2
    if [[ -f "$RUPTUR_ROOT/$relative" ]]; then
        cp -- "$RUPTUR_ROOT/$relative" "$destination"
    else
        ruptur_download "${ASSET_BASE_URL%/}/$relative" "$destination"
    fi
}
