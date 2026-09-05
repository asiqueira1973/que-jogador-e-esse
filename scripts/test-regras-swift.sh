#!/usr/bin/env bash
# Compila e roda a conferencia das regras da secao 11 (arquivos Swift puros, sem Firebase nem tvOS).
# Serve de rede de seguranca quando nao ha runtime de tvOS instalado para rodar o app inteiro.
set -euo pipefail
cd "$(dirname "$0")/.."
saida="$(mktemp -d)/regras"
swiftc -O \
  tvos-app/Tests/main.swift \
  tvos-app/Sources/Shared/Models/DataModel.swift \
  tvos-app/Sources/Shared/GameRules/GameRules.swift \
  tvos-app/Sources/Shared/FirebaseClient/RoomCode.swift \
  -o "$saida"
"$saida"
