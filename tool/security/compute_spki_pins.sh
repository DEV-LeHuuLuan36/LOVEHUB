#!/bin/bash
# ============================================================================
# compute_spki_pins.sh — Compute SHA-256 SPKI fingerprints for certificate
# pinning in network_security_config.xml.
#
# Usage:
#   ./tool/security/compute_spki_pins.sh <hostname> [<hostname> ...]
#
# Output:
#   One or more base64 SHA-256 SPKI pins per host. A live cert + a backup
#   pin (intermediate or alternate root) is recommended so a single
#   rotation does not brick the app.
#
# Reference:
#   https://owasp.org/www-community/controls/Certificate_and_Public_Key_Pinning
# ============================================================================
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <hostname> [<hostname> ...]" >&2
  exit 1
fi

extract_pin() {
  local host="$1"
  local port="${2:-443}"
  echo "--- $host:$port ---"

  # Use openssl s_client to fetch the cert chain, then parse the
  # SubjectPublicKeyInfo (SPKI) of each cert and base64 its SHA-256.
  #
  # We grab the full chain (intermediates included), so this script
  # outputs 2-3 pins per host. The first is usually the leaf; pick
  # two of them when populating network_security_config.xml.

  local tmpdir
  tmpdir=$(mktemp -d)
  local chain="$tmpdir/chain.pem"
  if ! openssl s_client -connect "$host:$port" -servername "$host" \
      -showcerts </dev/null 2>/dev/null > "$chain"; then
    echo "  (openssl s_client failed for $host:$port — network issue?)"
    rm -rf "$tmpdir"
    return 1
  fi

  # Split the chain into individual certs (each ends with END CERT).
  awk 'BEGIN{n=0} /-----BEGIN CERTIFICATE-----/{n++; out=sprintf("%s/cert-%02d.pem", "'"$tmpdir"'", n)} {print > out}' "$chain"

  local idx=0
  for f in "$tmpdir"/cert-*.pem; do
    idx=$((idx+1))
    if [ ! -s "$f" ]; then continue; fi
    local pin
    pin=$(openssl x509 -in "$f" -pubkey -noout 2>/dev/null \
          | openssl pkey -pubin -outform DER 2>/dev/null \
          | openssl dgst -sha256 -binary \
          | openssl enc -base64)
    echo "  pin #$idx = $pin"
  done

  rm -rf "$tmpdir"
}

for host in "$@"; do
  extract_pin "$host" 443
done