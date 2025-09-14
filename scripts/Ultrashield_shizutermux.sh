#!/data/data/com.termux/files/usr/bin/bash

# =====================================================
# Termux + Shizuku Shield Ultra-Expert Auto-Update
# Android 14 / Redmi 14C
# Root artificial + seguridad avanzada + alertas críticas Telegram
# Actualización dinámica de permisos y apps
# =====================================================

set -e

# --- Configuración ---
CHECK_INTERVAL=30       # Comprobación cada 30 segundos
DYNAMIC_APPS_URL="https://raw.githubusercontent.com/tu-repo/apps-sospechosas/main/apps.txt"
DYNAMIC_PERMS_URL="https://raw.githubusercontent.com/tu-repo/permisos-criticos/main/perms.txt"

# --- Configuración Telegram ---
TELEGRAM_TOKEN="YOUR TELEGRAM TOKEN"
TELEGRAM_CHAT_ID="Your telegram ID"

# --- Variables de monitorización ---
declare -A PERMISSIONS_LAST_STATE
declare -A APPS_LAST_STATE
SUSPICIOUS_APPS=()
PERMISSIONS_BLOCK=()

# --- Función: enviar alerta crítica a Telegram ---
send_telegram() {
    local MESSAGE="$1"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$MESSAGE" >/dev/null 2>&1
}

# --- Función: actualizar listas dinámicas ---
update_lists() {
    echo "[*] Actualizando listas dinámicas..."
    # Descargar apps sospechosas
    SUSPICIOUS_APPS=($(curl -s $DYNAMIC_APPS_URL | grep -v '^#' | grep -v '^$'))
    # Descargar permisos críticos
    PERMISSIONS_BLOCK=($(curl -s $DYNAMIC_PERMS_URL | grep -v '^#' | grep -v '^$'))
}

# --- Función: comprobar Shizuku ---
check_shizuku() {
    rish_auto pm list packages >/dev/null 2>&1
    return $?
}

# --- Función: iniciar Shizuku ---
start_shizuku() {
    am start -n moe.shizuku.privileged.api/.ui.MainActivity \
        --es extra_package_name com.termux >/dev/null 2>&1
    sleep 2
}

# --- Función: activar depuración inalámbrica ---
enable_adb_wifi() {
    settings put global adb_wifi_enabled 1 2>/dev/null
    sleep 1
}

# --- Función: probar root artificial ---
test_root() {
    su pm list packages >/dev/null 2>&1
    return $?
}

# --- Función: monitorizar y revocar permisos críticos ---
monitor_permissions() {
    for pkg in $(su pm list packages -3 | cut -f2 -d:); do
        for perm in "${PERMISSIONS_BLOCK[@]}"; do
            current=$(su dumpsys package $pkg | grep permission | grep granted | grep $perm || true)
            key="${pkg}_${perm}"
            last=${PERMISSIONS_LAST_STATE[$key]:-}

            if [ ! -z "$current" ] && [ "$current" != "$last" ]; then
                su pm revoke $pkg android.permission.$perm >/dev/null 2>&1 || true
                send_telegram "⚠️ Permiso crítico $perm revocado automáticamente para $pkg"
            fi

            PERMISSIONS_LAST_STATE[$key]="$current"
        done
    done
}

# --- Función: monitorizar apps sospechosas ---
monitor_suspicious_apps() {
    for app in "${SUSPICIOUS_APPS[@]}"; do
        status=$(su pm list packages -d | grep $app || true)
        last=${APPS_LAST_STATE[$app]:-}
        if [ -z "$status" ] && [ "$last" != "disabled" ]; then
            su pm disable-user $app >/dev/null 2>&1 || true
            send_telegram "⚠️ App sospechosa $app deshabilitada automáticamente"
            APPS_LAST_STATE[$app]="disabled"
        fi
    done
}

# --- Inicializar script ---
send_telegram "✅ Termux Shizuku Shield Ultra-Expert Auto-Update iniciado"

echo "[*] Iniciando Termux Shizuku Shield Ultra-Expert Auto-Update..."

while true; do
    # Actualizar listas cada ciclo
    update_lists

    # Mantener Shizuku activo
    if ! check_shizuku; then
        start_shizuku
        sleep 2
        if ! check_shizuku; then
            enable_adb_wifi
            start_shizuku
            sleep 2
        fi
    fi

    # Probar root artificial
    if test_root; then
        echo "[+] Root artificial activo ✅"
    else
        send_telegram "❌ Root artificial no activo - abre Shizuku y acepta permisos"
    fi

    # Monitorizar permisos críticos y apps sospechosas
    monitor_permissions
    monitor_suspicious_apps

    # Top 10 paquetes instalados
    echo "[*] Paquetes instalados (top 10):"
    su pm list packages | head -n 10

    sleep $CHECK_INTERVAL
done
