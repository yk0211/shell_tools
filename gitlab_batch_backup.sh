#!/bin/bash

if [ -z "${BASH_VERSION:-}" ]; then
    if command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    else
        echo "ERROR: this script requires bash, but bash is not installed." >&2
        exit 1
    fi
fi

TOKEN="your gitlab token"
GITLAB="gitlab base url"

export LC_ALL=C
set -xuo pipefail
mkdir -p backup
cd backup || exit 1

VISITED_FILE="$(mktemp)"
trap 'rm -f "$VISITED_FILE"' EXIT

is_visited() {
    grep -qx "$1" "$VISITED_FILE" 2>/dev/null
}

mark_visited() {
    echo "$1" >> "$VISITED_FILE"
}

curl_json() {
    local url=$1
    local attempt=1
    local resp
    while [ $attempt -le 3 ]; do
        resp=$(curl -s -w '\n%{http_code}' -H "PRIVATE-TOKEN: $TOKEN" "$url")
        local code=${resp##*$'\n'}
        resp=${resp%$'\n'*}
        if [ "$code" -ge 200 ] && [ "$code" -lt 300 ] 2>/dev/null; then
            echo "$resp"
            return 0
        fi
        echo "curl_json retry $attempt for $url (status=$code)" >&2
        attempt=$((attempt+1))
        sleep $((attempt*2))
    done
    echo "$resp"
    return 1
}

fetch_group() {
    gid=$1

    if is_visited "$gid"; then
        return
    fi
    mark_visited "$gid"
    
    page=1
    while true
    do
        projects=$(curl_json \
            "$GITLAB/api/v4/groups/$gid/projects?per_page=100&page=$page" \
            | tr -d '\000-\037\177')

        count=$(echo "$projects" | jq length)
        [ "$count" -eq 0 ] && break

        while IFS=$'\t' read path repo
        do
            echo "Backup: $path"
            mkdir -p "$(dirname "$path")"
            auth_repo=$(echo "$repo" | sed "s#https://#https://oauth2:$TOKEN@#")
            git clone --mirror "$auth_repo" "${path}.git"
        done < <(echo "$projects" | jq -r '.[] | "\(.path_with_namespace)\t\(.http_url_to_repo)"')

        page=$((page+1))
    done

    subgroups=$(curl_json \
        "$GITLAB/api/v4/groups/$gid/subgroups?per_page=100" \
        | tr -d '\000-\037\177')

    while read sgid
    do
        fetch_group "$sgid"
    done < <(echo "$subgroups" | jq -r '.[].id')
}

page=1
while true
do
    groups=$(curl_json \
        "$GITLAB/api/v4/groups?per_page=100&page=$page" \
        | tr -d '\000-\037\177')

    if ! echo "$groups" | jq -e 'type == "array"' >/dev/null 2>&1; then
        echo "error: $groups"
        break
    fi

    count=$(echo "$groups" | jq length)
    [ "$count" -eq 0 ] && break

    while read gid
    do
        fetch_group "$gid"
    done < <(echo "$groups" | jq -r '.[].id')

    page=$((page+1))
done