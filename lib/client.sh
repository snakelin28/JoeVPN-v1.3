#!/usr/bin/env bash
# lib/client.sh — 生成客户端配置（分享链接 / base64 订阅 / Clash YAML）

generate_clients() {
    local ip="${PUBLIC_IP}"
    local name="${CLIENT_NAME}"
    local outdir="${PROJECT_DIR}/clients"
    mkdir -p "${outdir}"

    # ---- 分享链接 ----
    local vless_link hy2_link
    vless_link="vless://${UUID}@${ip}:${REALITY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${REALITY_SNI}&fp=chrome&pbk=${REALITY_PUBLIC_KEY}&sid=${REALITY_SHORT_ID}&type=tcp#${name}-Reality"
    # Hy2 密码是 URL-safe（无 +/=），可直接放
    hy2_link="hysteria2://${HY2_PASSWORD}@${ip}:${HY2_PORT}?sni=${HY2_SNI}&insecure=1#${name}-Hy2"

    printf '%s\n%s\n' "${vless_link}" "${hy2_link}" > "${outdir}/links.txt"

    # AnyTLS（anytls-go 官方 URI 格式；密码同样是 URL-safe）
    if [[ "${ENABLE_ANYTLS:-0}" == "1" ]]; then
        local anytls_link
        anytls_link="anytls://${ANYTLS_PASSWORD}@${ip}:${ANYTLS_PORT}/?sni=${ANYTLS_SNI}&insecure=1#${name}-AnyTLS"
        printf '%s\n' "${anytls_link}" >> "${outdir}/links.txt"
    fi

    # ---- base64 订阅（小飞机原生格式）----
    base64 -w0 "${outdir}/links.txt" > "${outdir}/sub.txt"

    # ---- Clash.Meta / mihomo YAML（用模板渲染）----
    local tpl="${PROJECT_DIR}/templates/client.yaml"
    local yaml="${outdir}/${name}.yaml"
    # 带 #@anytls 标记的行：启用时去掉标记保留，关闭时整行删掉
    local anytls_filter
    if [[ "${ENABLE_ANYTLS:-0}" == "1" ]]; then
        anytls_filter='s/[[:space:]]*#@anytls$//'
    else
        anytls_filter='/#@anytls$/d'
    fi

    if [[ -f "${tpl}" ]]; then
        sed \
            -e "${anytls_filter}" \
            -e "s|__NAME__|${name}|g" \
            -e "s|__IP__|${ip}|g" \
            -e "s|__REALITY_PORT__|${REALITY_PORT}|g" \
            -e "s|__HY2_PORT__|${HY2_PORT}|g" \
            -e "s|__UUID__|${UUID}|g" \
            -e "s|__REALITY_SNI__|${REALITY_SNI}|g" \
            -e "s|__REALITY_PUBLIC_KEY__|${REALITY_PUBLIC_KEY}|g" \
            -e "s|__REALITY_SHORT_ID__|${REALITY_SHORT_ID}|g" \
            -e "s|__HY2_SNI__|${HY2_SNI}|g" \
            -e "s|__HY2_PASSWORD__|${HY2_PASSWORD}|g" \
            -e "s|__ANYTLS_PORT__|${ANYTLS_PORT:-}|g" \
            -e "s|__ANYTLS_PASSWORD__|${ANYTLS_PASSWORD:-}|g" \
            -e "s|__ANYTLS_SNI__|${ANYTLS_SNI:-}|g" \
            "${tpl}" > "${yaml}"
    fi

    log_ok "客户端配置已生成 -> ${outdir}/"
}

print_summary() {
    local anytls_line="" n_links
    if [[ "${ENABLE_ANYTLS:-0}" == "1" ]]; then
        anytls_line="
 AnyTLS    : ${ANYTLS_PORT}/TCP   (自签证书, 客户端跳过验证)"
    fi
    n_links="$(grep -c . "${PROJECT_DIR}/clients/links.txt" 2>/dev/null)" || n_links=0
    cat <<EOF

${C_GRN}================ JoeVPN 部署完成 ================${C_RST}
 服务器 IP : ${PUBLIC_IP}
 Reality   : ${REALITY_PORT}/TCP   SNI=${REALITY_SNI}
 Hysteria2 : ${HY2_PORT}/UDP    (${HY2_BANDWIDTH_MODE})${anytls_line}
 内存档位  : ${RAM_TIER} (${RAM_MB}MB)

 客户端文件（在 ${PROJECT_DIR}/clients/）:
   • links.txt        ${n_links} 条分享链接（手机小飞机粘这个）
   • sub.txt          base64 订阅串
   • ${CLIENT_NAME}.yaml   Clash.Meta / mihomo 配置

 分享链接:
$(sed 's/^/   /' "${PROJECT_DIR}/clients/links.txt")
${C_GRN}===============================================${C_RST}
EOF
}
