#!/usr/bin/env bash
# Tokens @@VAR@@ são substituídos uma vez. Valores nunca são executados ou
# reinterpretados como template. mode=yaml também protege interpolação Compose.
ruptur_render() {
    local template=$1 destination=$2 mode=${3:-yaml} line rest key value result temporary
    [[ -f "$template" ]] || { ruptur_error "Template ausente: $template"; return 1; }
    temporary=$(mktemp "${destination}.XXXXXX") || return
    while IFS= read -r line || [[ -n "$line" ]]; do
        rest=$line; result=
        while [[ "$rest" == *@@* ]]; do
            result+=${rest%%@@*}; rest=${rest#*@@}
            if [[ "$rest" != *@@* ]]; then rm -f -- "$temporary"; ruptur_error 'Token incompleto'; return 1; fi
            key=${rest%%@@*}; rest=${rest#*@@}
            if [[ ! "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ || ! -v "$key" ]]; then
                rm -f -- "$temporary"; ruptur_error "Variável de template ausente: $key"; return 1
            fi
            value=${!key}
            if [[ "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
                rm -f -- "$temporary"; ruptur_error "Valor multilinha: $key"; return 1
            fi
            if [[ "$mode" == yaml ]]; then
                value=${value//\'/\'\'}; value=${value//\$/\$\$}
            fi
            result+=$value
        done
        printf '%s\n' "$result$rest" >> "$temporary" || { rm -f -- "$temporary"; return 1; }
    done < "$template"
    chmod 600 "$temporary" && mv -- "$temporary" "$destination"
}
