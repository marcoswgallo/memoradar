#!/bin/bash
# Roda os testes. Sem o Xcode, a compilação limpa às vezes não encontra o plugin
# TestingMacros. Só esse erro específico é repetido; qualquer outra falha é real.
set -uo pipefail
cd "$(dirname "$0")/.."

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
for _ in 1 2 3; do
    if swift test "$@" >"$LOG" 2>&1; then
        grep -vE 'ld: warning: search path' "$LOG" | tail -n 40
        exit 0
    fi
    if ! grep -q "plugin for module 'TestingMacros' not found" "$LOG"; then
        cat "$LOG"
        exit 1
    fi
    touch Tests/MemoRadarCoreTests/*.swift
done
cat "$LOG"
exit 1
