#!/usr/bin/env bash
ruptur_grafana_resources() {
    local destination=${1:-/opt/monitor-ruptur}
    # Recursos locais acompanham a mesma revisão do instalador.
    mkdir -p "$destination" || return
    cp -R "$RUPTUR_ROOT/Extras/Grafana/monitor-ruptur/." "$destination/" || return
    mkdir -p "$destination/grafana/dashboards" "$destination/grafana/provisioning/dashboards" || return
    command -v jq >/dev/null || { ruptur_error 'jq é necessário para gerar o dashboard'; return 1; }
    jq --arg brand "$BRAND_NAME" --arg url "$BASE_URL" --arg video "$VIDEO_URL" --arg node "$url_nodeexporter" \
        'walk(if type == "string" then
            if . == "@@BRAND_NAME@@" then $brand
            elif . == "@@BASE_URL@@" then $url
            elif . == "@@VIDEO_URL@@" then $video
            elif . == "@@NODE_EXPORTER@@" then $node
            else . end else . end)' \
        "$RUPTUR_ROOT/templates/grafana/dashboard.json.template" > "$destination/grafana/dashboards/dashboard.json" || return
    ruptur_render "$RUPTUR_ROOT/templates/grafana/dashboard.yml.template" "$destination/grafana/provisioning/dashboards/dashboard.yml" || return
    # Os containers usam usuários sem privilégios; estes arquivos não contêm segredos.
    chmod 755 "$destination" "$destination/grafana" "$destination/grafana/dashboards" \
        "$destination/grafana/provisioning" "$destination/grafana/provisioning/dashboards" \
        "$destination/grafana/provisioning/datasources" "$destination/prometheus" || return
    chmod 644 "$destination/grafana/grafana.ini" "$destination/grafana/dashboards/dashboard.json" \
        "$destination/grafana/provisioning/dashboards/dashboard.yml"
}
