#!/usr/bin/env bash
# Prévient sur ntfy quand un VPS OVH (VPS-2 ou plus, au moins 8 Go) est commandable sous Linux en France.
set -euo pipefail

API="https://eu.api.ovh.com/1.0"
FRANCE='["eu-west-gra","eu-west-rbx","eu-west-sbg"]'

# Le catalogue donne la mémoire par produit ; on garde les gammes VPS-2 et plus, hors zones locales (.LZ).
plans=$(curl -fsS "$API/order/catalog/public/vps?ovhSubsidiary=FR" | jq -r '
  (.products | map({key: .name, value: .blobs.technical.memory.size}) | from_entries) as $ram
  | .plans[]
  | select((.planCode | test("^vps-20[0-9]{2}-model([2-9]|[1-9][0-9])$")) and ($ram[.product] // 0) >= 8)
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
