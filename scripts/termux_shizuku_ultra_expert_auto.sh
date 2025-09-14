#!/data/data/com.termux/files/usr/bin/bash
# =====================================================
# Termux + Shizuku Shield Ultra-Expert Auto-Update
# Android 14 / Redmi 14C
# Root artificial + seguridad avanzada + alertas críticas Telegram
# =====================================================

set -e

# --- Configuración ---
CHECK_INTERVAL=30
DYNAMIC_APPS_URL="https://raw.githubusercontent.com/TU_USUARIO/termux-shizuku-shield/main/data/apps.txt"
DYNAMIC_PERMS_URL="https://raw.githubusercontent.com/TU_USUARIO/termux-shizuku-shield/main/data/perms.txt"

# --- Telegram ---
TELEGRAM_TOKEN="YOUR TG TOKEN"
TELEGRAM_CHAT_ID="USER ID"

declare -A PERMISSIONS_LAST_STATE
declare -A APPS_LAST_STATE
SUSPICIOUS_APPS=()
PERMISSIONS_BLOCK=()

# --- Funciones ---
send_telegram() {
    local MESSAGE="$1"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" -d text="$MESSAGE" >/dev/null 2>&1
}

update_lists() {
    echo "[*] Actualizando listas dinámicas..."
    SUSPICIOUS_APPS=($(curl -s $DYNAMIC_APPS_URL | grep -v '^#' | grep -v '^$'))
    PERMISSIONS_BLOCK=($(curl -s $DYNAMIC_PERMS_URL | grep -v '^#' | grep -v '^$'))
}

check_shizuku() {
    rish_auto pm list packages >/dev/null 2>&1
    return $?
}

start_shizuku() {
    am start -n moe.shizuku.privileged.api/.ui.MainActivity \
        --es extra_package_name com.termux >/dev/null 2>&1
    sleep 2
}

enable_adb_wifi() {
    settings put global adb_wifi_enabled 1 2>/dev/null
    sleep 1
}

test_root() {
    su pm list packages >/dev/null 2>&1
    return $?
}

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

# --- Inicio ---
send_telegram "✅ Termux Shizuku Shield Ultra-Expert Auto-Update iniciado"
echo "[*] Iniciando Termux Shizuku Shield Ultra-Expert Auto-Update..."

while true; do
    update_lists

    if ! check_shizuku; then
        start_shizuku
        sleep 2
        if ! check_shizuku; then
            enable_adb_wifi
            start_shizuku
            sleep 2
        fi
    fi

    if test_root; then
        echo "[+] Root artificial activo ✅"
    else
        send_telegram "❌ Root artificial no activo - abre Shizuku y acepta permisos"
    fi

    monitor_permissions
    monitor_suspicious_apps

    echo "[*] Paquetes instalados (top 10):"
    su pm list packages | head -n 10

    sleep $CHECK_INTERVAL
done
