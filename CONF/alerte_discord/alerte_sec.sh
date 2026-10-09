#!/bin/bash
# URL de ton Webhook Slack ou Teams
WEBHOOK_URL="https://discord.com/api/webhooks/1555745942538555422/cfKzpNUG-7Ary0TIit6P8c6ujtzQafJZjOalE74ty6BO-6gIbP06C9EL6M-tWSLogTiz"

# Boucle pour lire chaque ligne de log envoyée par syslog-ng
while read MESSAGE; do
    # Formatage de la requête JSON (la syntaxe exacte peut varier légèrement selon Teams/Slack)
    PAYLOAD="{\"content\": \"*Alerte de Sécurité (Snort)* : $MESSAGE\"}"

    # Envoi de la requête HTTP POST
    /usr/bin/curl -s -X POST -H 'Content-type: application/json' --data "$PAYLOAD" "$WEBHOOK_URL"
done