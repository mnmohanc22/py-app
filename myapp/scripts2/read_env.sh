#!/bin/bash
# /opt/scripts/read_env.sh

load_env() {
    local env_file="${1:?load_env requires a file path}"

    [ -f "$env_file" ] \
        || { echo "[read_env] ERROR: file not found: $env_file"; return 1; }

    [ -r "$env_file" ] \
        || { echo "[read_env] ERROR: file not readable: $env_file"; return 1; }

    local loaded=0
    local skipped=0

    while IFS= read -r line || [ -n "$line" ]; do

        # Skip blank lines
        [[ -z "$line" ]]            && continue

        # Skip comment lines
        [[ "$line" =~ ^\s*# ]]      && continue

        # Skip lines without =
        [[ "$line" != *"="* ]]      && { skipped=$((skipped+1)); continue; }

        # Strip whitespace and export prefix
        line=$(echo "$line" | sed \
            's/^[[:space:]]*//;
             s/[[:space:]]*$//;
             s/[[:space:]]*#.*$//;
             s/^export[[:space:]]*//')

        local key="${line%%=*}"
        local value="${line#*=}"

        # Strip whitespace from key
        key=$(echo "$key" | tr -d '[:space:]')

        # Skip empty key
        [[ -z "$key" ]] && { skipped=$((skipped+1)); continue; }

        # Strip surrounding quotes
        [[ "$value" =~ ^\".*\"$ ]] && value="${value#\"}" && value="${value%\"}"
        [[ "$value" =~ ^\'.*\'$ ]] && value="${value#\'}" && value="${value%\'}"

        export "$key=$value"
        loaded=$((loaded+1))

    done < "$env_file"

    echo "[read_env] $env_file → loaded=$loaded skipped=$skipped"
    return 0
}