#!/bin/bash
# /opt/scripts/read_env.sh
# Source this file — do not execute directly
# Provides: load_env <file>

load_env() {
    local env_file="${1:?Usage: load_env <env_file>}"
    local loaded=0
    local skipped=0

    [ -f "$env_file" ] \
        || { echo "[read_env] ERROR: not found: $env_file"; return 1; }

    [ -r "$env_file" ] \
        || { echo "[read_env] ERROR: not readable: $env_file"; return 1; }

    while IFS= read -r line || [ -n "$line" ]; do

        # Skip blank
        [[ -z "$line" ]]       && continue

        # Skip comments
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        # Skip no =
        [[ "$line" != *"="* ]] && { skipped=$((skipped+1)); continue; }

        # Clean line
        line="${line#"${line%%[![:space:]]*}"}"   # ltrim
        line="${line%"${line##*[![:space:]]}"}"   # rtrim
        line="${line%%[[:space:]]#*}"             # strip inline comment
        line="${line#export }"                    # strip export prefix

        local key="${line%%=*}"
        local value="${line#*=}"

        # Clean key
        key="${key// /}"

        # Skip empty key
        [[ -z "$key" ]] && { skipped=$((skipped+1)); continue; }

        # Strip quotes from value
        [[ "$value" == \"*\" ]] && value="${value#\"}" && value="${value%\"}"
        [[ "$value" == \'*\' ]] && value="${value#\'}" && value="${value%\'}"

        export "$key=$value"
        loaded=$((loaded+1))

    done < "$env_file"

    echo "[read_env] loaded=$loaded skipped=$skipped from $env_file"
    return 0
}