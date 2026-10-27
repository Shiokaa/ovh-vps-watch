#!/usr/bin/env bash
# Prévient sur ntfy quand un VPS OVH d'au moins 8 Go est commandable sous Linux en France.
set -euo pipefail

API="https://eu.api.ovh.com/1.0"
MIN_RAM_GB="${MIN_RAM_GB:-8}"
FRANCE='["eu-west-gra","eu-west-rbx","eu-west-sbg"]'

# Le catalogue donne la mémoire par produit ; on n'en garde que les gammes VPS-n, hors zones locales (.LZ).
plans=$(curl -fsS "$API/order/catalog/public/vps?ovhSubsidiary=FR" | jq -r --argjson min "$MIN_RAM_GB" '
  (.products | map({key: .name, value: .blobs.technical.memory.size}) | from_entries) as $ram
  | .plans[]
  | select((.planCode | test("^vps-20[0-9]{2}-model[0-9]+$")) and ($ram[.product] // 0) >= $min)
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
