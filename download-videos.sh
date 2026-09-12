#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if ! command -v sbcl >/dev/null 2>&1; then
    echo "ERROR: sbcl is not installed or on PATH."
    exit 42
fi

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
LVL_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

SCRIPT_FILE="${LVL_DIR}/src/downloader-script.lisp"

sbcl --script "$SCRIPT_FILE" "$1"
