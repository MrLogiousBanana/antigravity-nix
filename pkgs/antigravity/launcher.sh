#!/usr/bin/env bash
set -e

# Antigravity Profile Launcher
# Supports multi-profile isolation (Personal / Workspace) with dual-boot NTFS sync

PROG_NAME="$(basename "$0")"

# Auto-detect profile from program name if not explicitly passed
if [ "$PROG_NAME" = "antigravity-personal" ]; then
    PROFILE="Personal"
elif [ "$PROG_NAME" = "antigravity-workspace" ]; then
    PROFILE="Workspace"
else
    PROFILE="$1"
    if [ "$PROFILE" = "Personal" ] || [ "$PROFILE" = "Workspace" ]; then
        shift || true
    else
        PROFILE="Personal"
    fi
fi

BASE_DIR="$HOME"
PROFILE_LOWER="$(echo "$PROFILE" | tr '[:upper:]' '[:lower:]')"
PROFILE_DIR="$BASE_DIR/.antigravity-profiles/$PROFILE_LOWER"

# Locate shared NTFS data directory across known mount points
if [ -d "/vault/Документы/Antigravity/$PROFILE" ]; then
    SHARED_DIR="/vault/Документы/Antigravity/$PROFILE"
elif [ -d "$BASE_DIR/Документы/Antigravity/$PROFILE" ]; then
    SHARED_DIR="$BASE_DIR/Документы/Antigravity/$PROFILE"
elif [ -d "/mnt/02DA55FADA55EB05/Документы/Antigravity/$PROFILE" ]; then
    SHARED_DIR="/mnt/02DA55FADA55EB05/Документы/Antigravity/$PROFILE"
else
    SHARED_DIR="/vault/Документы/Antigravity/$PROFILE"
fi

USER_DATA_DIR="$BASE_DIR/.config/Antigravity-$PROFILE"

# Notify user if the shared storage is not accessible
if [ ! -d "$SHARED_DIR" ]; then
    echo "Warning: Shared profile directory not found at $SHARED_DIR" >&2
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u normal "Antigravity" "Внимание: Папка $SHARED_DIR не найдена. Создаю локальный профиль..." 2>/dev/null || true
    fi
    mkdir -p "$SHARED_DIR"
fi

# 1. Clean up stale Singleton locks if process is not running
LOCK_FILE="$USER_DATA_DIR/SingletonLock"
if [ -L "$LOCK_FILE" ]; then
    LOCK_TARGET=$(readlink "$LOCK_FILE" 2>/dev/null || true)
    LOCK_PID=$(echo "$LOCK_TARGET" | grep -oE '[0-9]+$' || true)
    if [ -n "$LOCK_PID" ] && ! kill -0 "$LOCK_PID" 2>/dev/null; then
        rm -f "$USER_DATA_DIR/SingletonLock" "$USER_DATA_DIR/SingletonSocket" "$USER_DATA_DIR/SingletonCookie" 2>/dev/null || true
    fi
fi

# 2. Ensure profile directory structure
mkdir -p "$PROFILE_DIR/.gemini"
mkdir -p "$PROFILE_DIR/.config"
mkdir -p "$USER_DATA_DIR"
mkdir -p "$SHARED_DIR/config"
touch "$SHARED_DIR/GEMINI.md"

# Safe transition if directories are regular folders instead of symlinks
if [ -d "$PROFILE_DIR/.gemini/antigravity" ] && [ ! -L "$PROFILE_DIR/.gemini/antigravity" ]; then
    mkdir -p "$SHARED_DIR/conversations" "$SHARED_DIR/brain" "$SHARED_DIR/annotations"
    cp -rn "$PROFILE_DIR/.gemini/antigravity/conversations"/* "$SHARED_DIR/conversations/" 2>/dev/null || true
    cp -rn "$PROFILE_DIR/.gemini/antigravity/brain"/* "$SHARED_DIR/brain/" 2>/dev/null || true
    cp -rn "$PROFILE_DIR/.gemini/antigravity/annotations"/* "$SHARED_DIR/annotations/" 2>/dev/null || true
    rm -rf "$PROFILE_DIR/.gemini/antigravity"
fi
if [ -d "$PROFILE_DIR/.gemini/config" ] && [ ! -L "$PROFILE_DIR/.gemini/config" ]; then
    rm -rf "$PROFILE_DIR/.gemini/config"
fi

# 3. Link shared data into profile's .gemini
ln -sfn "$SHARED_DIR" "$PROFILE_DIR/.gemini/antigravity"
ln -sfn "$SHARED_DIR/config" "$PROFILE_DIR/.gemini/config"
ln -sfn "$SHARED_DIR/GEMINI.md" "$PROFILE_DIR/.gemini/GEMINI.md"

# 4. Link native local user-data directory for Electron
ln -sfn "$USER_DATA_DIR" "$PROFILE_DIR/.config/Antigravity"

# 5. Mirror user configs into profile config (except Antigravity itself)
for cfg in "$BASE_DIR/.config"/*; do
    [ -e "$cfg" ] || continue
    name="$(basename "$cfg")"
    if [ "$name" != "Antigravity" ] && [ ! -e "$PROFILE_DIR/.config/$name" ]; then
        ln -sfn "$cfg" "$PROFILE_DIR/.config/$name" 2>/dev/null || true
    fi
done

# 6. Symlink standard user environment folders
for item in .local .ssh .gitconfig .bashrc .bash_profile .profile .zshrc Downloads Desktop Documents Документы Загрузки Projects .var .mozilla .pki .icons .themes .cache Изображения Медиа Видео Музыка Pictures Music Videos; do
    if [ -e "$BASE_DIR/$item" ] && [ ! -e "$PROFILE_DIR/$item" ]; then
        ln -sfn "$BASE_DIR/$item" "$PROFILE_DIR/$item" 2>/dev/null || true
    fi
done

# 7. Ensure token files are local files on native filesystem
if [ -L "$PROFILE_DIR/.gemini/jetski-standalone-oauth-token" ]; then
    rm -f "$PROFILE_DIR/.gemini/jetski-standalone-oauth-token"
fi
if [ -L "$PROFILE_DIR/.gemini/google_accounts.json" ]; then
    rm -f "$PROFILE_DIR/.gemini/google_accounts.json"
fi

# Bidirectional sync helper
sync_file_bidirectional() {
    local local_f="$1"
    local shared_f="$2"

    if [ -f "$shared_f" ] && [ ! -f "$local_f" ]; then
        cp -f "$shared_f" "$local_f" 2>/dev/null || true
        chmod 600 "$local_f" 2>/dev/null || true
    elif [ -f "$local_f" ] && [ ! -f "$shared_f" ]; then
        cp -f "$local_f" "$shared_f" 2>/dev/null || true
    elif [ -f "$local_f" ] && [ -f "$shared_f" ]; then
        if ! cmp -s "$local_f" "$shared_f"; then
            if [ "$shared_f" -nt "$local_f" ]; then
                cp -f "$shared_f" "$local_f" 2>/dev/null || true
                chmod 600 "$local_f" 2>/dev/null || true
            else
                cp -f "$local_f" "$shared_f" 2>/dev/null || true
            fi
        fi
    fi
}

sync_file_bidirectional "$PROFILE_DIR/.gemini/jetski-standalone-oauth-token" "$SHARED_DIR/jetski-standalone-oauth-token"
sync_file_bidirectional "$PROFILE_DIR/.gemini/google_accounts.json" "$SHARED_DIR/google_accounts.json"

export HOME="$PROFILE_DIR"
export REAL_HOME="$BASE_DIR"

if [ "$PROFILE" = "Personal" ]; then
    DISPLAY_NAME="Antigravity 🍃"
else
    DISPLAY_NAME="Antigravity 💼"
fi

# Isolate D-Bus session bus to force in-file auth storage and prevent keyring collision
export DBUS_SESSION_BUS_ADDRESS=""
export GODEBUG="${GODEBUG:+$GODEBUG,}netdns=cgo"

# Wayland and Desktop environment hints
export CHROME_DESKTOP="antigravity-$PROFILE_LOWER.desktop"
export ANTIGRAVITY_APP_ID="antigravity-$PROFILE_LOWER"
export ANTIGRAVITY_DISPLAY_NAME="$DISPLAY_NAME"

mkdir -p "$USER_DATA_DIR/logs"

# Binary executable path provided by Nix derivation
ANTIGRAVITY_BIN="@ANTIGRAVITY_EXEC@"
if [ ! -x "$ANTIGRAVITY_BIN" ]; then
    echo "Error: Antigravity binary not found at $ANTIGRAVITY_BIN" >&2
    exit 1
fi

"$ANTIGRAVITY_BIN" \
    --user-data-dir="$USER_DATA_DIR" \
    "$@" >> "$USER_DATA_DIR/logs/electron-stdout.log" 2>&1 &
APP_PID=$!

# Background watcher to sync tokens back to shared storage
(
    while kill -0 "$APP_PID" 2>/dev/null; do
        sleep 5
        if [ -f "$PROFILE_DIR/.gemini/jetski-standalone-oauth-token" ] && [ -f "$SHARED_DIR/jetski-standalone-oauth-token" ]; then
            if ! cmp -s "$PROFILE_DIR/.gemini/jetski-standalone-oauth-token" "$SHARED_DIR/jetski-standalone-oauth-token"; then
                if [ "$PROFILE_DIR/.gemini/jetski-standalone-oauth-token" -nt "$SHARED_DIR/jetski-standalone-oauth-token" ]; then
                    cp -f "$PROFILE_DIR/.gemini/jetski-standalone-oauth-token" "$SHARED_DIR/jetski-standalone-oauth-token" 2>/dev/null || true
                fi
            fi
        fi
        if [ -f "$PROFILE_DIR/.gemini/google_accounts.json" ] && [ -f "$SHARED_DIR/google_accounts.json" ]; then
            if ! cmp -s "$PROFILE_DIR/.gemini/google_accounts.json" "$SHARED_DIR/google_accounts.json"; then
                if [ "$PROFILE_DIR/.gemini/google_accounts.json" -nt "$SHARED_DIR/google_accounts.json" ]; then
                    cp -f "$PROFILE_DIR/.gemini/google_accounts.json" "$SHARED_DIR/google_accounts.json" 2>/dev/null || true
                fi
            fi
        fi
    done
) &
WATCHER_PID=$!

cleanup() {
    trap - EXIT INT TERM HUP
    kill "$WATCHER_PID" 2>/dev/null || true
    if [ -f "$PROFILE_DIR/.gemini/jetski-standalone-oauth-token" ]; then
        cp -f "$PROFILE_DIR/.gemini/jetski-standalone-oauth-token" "$SHARED_DIR/jetski-standalone-oauth-token" 2>/dev/null || true
    fi
    if [ -f "$PROFILE_DIR/.gemini/google_accounts.json" ]; then
        cp -f "$PROFILE_DIR/.gemini/google_accounts.json" "$SHARED_DIR/google_accounts.json" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM HUP

wait "$APP_PID" 2>/dev/null || true
cleanup
