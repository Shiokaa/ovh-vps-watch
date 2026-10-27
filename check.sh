#!/usr/bin/env bash
# Prévient sur ntfy quand un VPS-2, 3 ou 4 d'OVH est commandable sous Linux en France.
set -euo pipefail

API="https://eu.api.ovh.com/1.0"
FRANCE='["eu-west-gra","eu-west-rbx","eu-west-sbg"]'

# Toutes les années de la gamme, hors zones locales (.LZ) ; le VPS-1 est trop petit.
plans=$(curl -fsS "$API/order/catalog/public/vps?ovhSubsidiary=FR" | jq -r '
  .plans[]
  | select(.planCode | test("^vps-20[0-9]{2}-model[2-4]$"))
  | "\(.planCode)\t\(.invoiceName)"')

found=""
while IFS=$'\t' read -r code name; do
  dcs=$(curl -fsS "$API/vps/order/rule/datacenter?ovhSubsidiary=FR&planCode=$code" | jq -r --argjson fr "$FRANCE" '
    [.datacenters[] | select(.linuxStatus == "available" and (.code | IN($fr[]))) | .datacenter] | join(", ")')
  echo "$name ($code) : ${dcs:-rupture}"
  [ -n "$dcs" ] && found+="$name : $dcs"$'\n'
done <<< "$plans"

[ -z "$found" ] && exit 0

curl -fsS -H "Title: VPS OVH disponible en France" -H "Click: https://www.ovhcloud.com/fr/vps/" \
  -d "$found" "https://ntfy.sh/$NTFY_TOPIC" > /dev/null
echo "Notification envoyée."
