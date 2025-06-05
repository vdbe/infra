#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# SOPS_AGE_KEY_FILE="./key.txt"
# export SOPS_AGE_KEY_FILE

tf_console() {
  echo "$1" | terraform console
}

tf_import() {
  if ! echo "$EXISTING_RESOURCES" | grep -q "^${1}$"; then
    echo "[+] Importing $1 $2"
    terraform import "$1" "$2"
  fi
}

echo "[+] Updating data for imports"
# Update all data sources required for importing
terraform apply \
  -target=data.cloudflare_zones.domain \
  -target=data.cloudflare_dns_records.infra-terraform \
  -target=cloudflare_zero_trust_access_identity_providers.domain \
  -auto-approve

# Get zone info
ZONE_JSON="$(tf_console 'jsonencode(data.cloudflare_zones.domain.result[0])' | jq -r fromjson)"
ZONE_NAME="$(echo "$ZONE_JSON" | jq -r .name)"
ZONE_ID="$(echo "$ZONE_JSON" | jq -r .id)"

# Existing state
EXISTING_RESOURCES="$(terraform state list | grep -ve "^data\." || true)"

# Import missing dns records
tf_console "jsonencode(data.cloudflare_dns_records.infra-terraform)" | jq -r \
  --arg ZONE_NAME "$ZONE_NAME" \
  ' 
  fromjson | .result[] |
  {
    subdomain: (
      if .name == $ZONE_NAME then
        "root"
      else
        .name | sub("\\." + $ZONE_NAME + "$"; "")
      end
    ),
    type: .type | ascii_downcase,
    id
  } | [.subdomain, .type, .id ] | @tsv
  ' | while IFS=$'\t' read -r subdomain type id; do
    tf_import  "cloudflare_dns_record.${subdomain}-${type}" "${ZONE_ID}/${id}"
  done

OIDC_PROVIDER_ID="$(tf_console "nonsensitive(jsonencode(data.cloudflare_zero_trust_access_identity_providers.domain.result))" | jq -r \
  '[fromjson | .[] | select(.name == "kanidm")][0] | .id')"
if [[ "$OIDC_PROVIDER_ID" != "null" ]]; then
     tf_import  "cloudflare_zero_trust_access_identity_provider.kanidm" "zones/${ZONE_ID}/${OIDC_PROVIDER_ID}"
fi

echo "[+] Imported resoureces"


