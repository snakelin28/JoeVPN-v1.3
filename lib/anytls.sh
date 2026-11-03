#!/usr/bin/env bash
# lib/anytls.sh — AnyTLS 节点：默认值 / 内核版本检查 / 生成密码
# 证书复用 lib/hy2.sh 生成的自签证书（不需要域名），所以必须在 gen_hy2 之后调用。

# 兼容旧 config.conf（v1.2 及以前没有这些字段，restore.sh 恢复旧备份时也会是旧文件）：
# 缺字段就用默认值，避免 set -u 下变量未定义直接退出。
: "${ENABLE_ANYTLS:=1}"
: "${ANYTLS_PORT:=8443}"
: "${ANYTLS_PASSWORD:=}"
: "${ANYTLS_SNI:=}"

# sing-box 从 1.12.0 起才有 anytls 入站；低于此版本自动关掉 AnyTLS，不影响另外两个节点
_anytls_supported() {
    local v
    v="$(_installed_version)"
    [[ -n "${v}" ]] || return 1
    [[ "$(printf '%s\n%s\n' "1.12.0" "${v}" | sort -V | head -n1)" == "1.12.0" ]]
}

gen_anytls() {
    if [[ "${ENABLE_ANYTLS}" != "1" ]]; then
        log_info "AnyTLS 已在 config.conf 中关闭，跳过"
        return 0
    fi

    if ! _anytls_supported; then
        log_warn "当前 sing-box 版本 $(_installed_version) 不支持 AnyTLS（需 ≥ 1.12.0），本次跳过 AnyTLS"
        ENABLE_ANYTLS=0
        return 0
    fi

    # 和 Hy2 同一张自签证书，SNI 留空则沿用 HY2_SNI
    [[ -n "${ANYTLS_SNI}" ]] || ANYTLS_SNI="${HY2_SNI}"

    if [[ ! -f "${SB_CERT_DIR}/server.crt" || ! -f "${SB_CERT_DIR}/server.key" ]]; then
        log_err "找不到自签证书，AnyTLS 需要先运行 gen_hy2 生成证书"
        exit 1
    fi

    # URL-safe 密码（去掉 + / =），可直接放进 anytls:// 分享链接
    if [[ -z "${ANYTLS_PASSWORD}" ]]; then
        ANYTLS_PASSWORD="$(openssl rand -base64 24 | tr '+/' '-_' | tr -d '=')"
        save_conf_value ANYTLS_PASSWORD "${ANYTLS_PASSWORD}"
        log_info "生成 AnyTLS 密码"
    fi
    log_ok "AnyTLS 就绪（${ANYTLS_PORT}/TCP，复用自签证书）"
}
