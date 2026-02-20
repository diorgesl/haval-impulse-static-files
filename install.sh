#!/bin/sh

# ================================
# Variaveis globais
# ================================
ROLLBACK_ENABLED=true

# ================================
# Funcoes basicas
# ================================
log() {
    echo "[$1] $(date +%H:%M:%S) $2"
}

die() {
    log "ERR" "$1"
    exit 1
}

# ================================
# Rollback simples
# ================================
cleanup() {
    if [ $? -eq 0 ]; then
        exit 0
    fi

    if [ "$ROLLBACK_ENABLED" = false ]; then
        exit 0
    fi

    log "INFO" "Executando rollback..."

    pkill -f fridaserver 2>/dev/null || true
    rm -f shizuku.apk haval.apk 2>/dev/null || true

    log "INFO" "Rollback concluido"
}

trap cleanup EXIT

# ================================
# Funcoes de versao
# ================================
get_latest_release() {
    repo=${1#https://github.com/}
    repo=${repo%.git}

    curl -s "https://api.github.com/repos/$repo/releases/latest" \
        | grep browser_download_url \
        | cut -d\" -f4
}

# ================================
# Download com verificacao
# ================================
download() {
    url="$1"
    file="$2"
    name="$3"

    if [ -f "$file" ] && [ -s "$file" ]; then
        log "INFO" "Arquivo $file ja existe"
        return
    fi

    log "INFO" "Baixando $name..."

    curl -L --progress-bar -o "$file" "$url" \
        || die "Falha no download de $file"

    [ -f "$file" ] && [ -s "$file" ] \
        || die "Arquivo $file vazio/inexistente"
}

# ================================
# Instalacao de aplicativo
# ================================
install_app() {
    apk="$1"
    name="$2"

    [ ! -f "$apk" ] && die "$apk nao encontrado"

    log "INFO" "Instalando $name..."

    pm install -r "$apk" \
        || die "Falha na instalacao de $name"
}

# ================================
# Script principal
# ================================
main() {
    log "INFO" "Iniciando instalacao compacta..."

    cd . || die "Falha ao acessar diretorio"

    # ----------------------------
    # Fase 1: Downloads
    # ----------------------------
    log "INFO" "Fase 1: Downloads"

    download "https://haval.joaoiot.com.br/fridaserver.rar" \
             "fridaserver" \
             "fridaserver"

    download "https://haval.joaoiot.com.br/fridainject.rar" \
             "fridainject" \
             "fridainject"

    download "https://haval.joaoiot.com.br/system_server.js" \
             "system_server.js" \
             "system_server.js"

    download "$(get_latest_release "https://github.com/RikkaApps/Shizuku")" \
             "shizuku.apk" \
             "Shizuku APK"

    download "$(get_latest_release "https://github.com/diorgesl/haval-app-tool-multimidia")" \
             "haval.apk" \
             "Haval APK"

    # ----------------------------
    # Fase 2: Permissoes
    # ----------------------------
    log "INFO" "Fase 2: Permissoes"

    chmod +x fridaserver fridainject \
        || die "Falha nas permissoes"

    # ----------------------------
    # Fase 3: Servicos
    # ----------------------------
    log "INFO" "Fase 3: Servicos"

    if ! pgrep fridaserver >/dev/null; then
        [ -x "./fridaserver" ] \
            || die "fridaserver nao executavel"

        setsid ./fridaserver >/dev/null 2>&1 < /dev/null &
        sleep 2

        pgrep fridaserver >/dev/null \
            || die "fridaserver nao iniciou"
    fi

    # ----------------------------
    # Injecao
    # ----------------------------
    [ -f "system_server.js" ] \
        || die "system_server.js nao encontrado"

    SYSTEM_PID=$(pidof system_server) \
        || die "system_server nao encontrado"

    ./fridainject -p "$SYSTEM_PID" -s system_server.js &
    sleep 1

    log "INFO" "Injecao iniciada"

    # ----------------------------
    # Fase 4: Aplicativos
    # ----------------------------
    log "INFO" "Fase 4: Aplicativos"

    install_app "shizuku.apk" "Shizuku"
    install_app "haval.apk" "Haval App"

    # ----------------------------
    # Limpeza final
    # ----------------------------
    rm -f shizuku.apk haval.apk
    ROLLBACK_ENABLED=false

    echo "🎉 Instalacao concluida!"
}

# ================================
# Executa
# ================================
main "$@"