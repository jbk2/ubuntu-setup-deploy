#!/bin/bash

# Variables
CF_API_TOKEN="M4EoSJUf8erouwLe0SV6mNhLdG1J0skfsHFw4I9F"
ZONE_ID="8914d5652221e66de395d0d3b2a63210"
RECORD_ID1="6dc3fdb2420bd2c36d2e44eb8c2e0999"  # Record ID for ctrlaltinsure.com
RECORD_NAME1="ctrlaltinsure.com"
RECORD_ID2="00cc89e395517ddd7b6ace5d65b89876"  # Record ID for www.ctrlaltinsure.com
RECORD_NAME2="www.ctrlaltinsure.com"

log() {
  local MESSAGE="$1"
  logger -t update-dns "$MESSAGE"
  echo "$MESSAGE" 
}

log "Starting DNS update"

# Fetch IMDSv2 token
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
if [ -z "$TOKEN" ]; then
  log "Failed to get IMDSv2 token"
  exit 1
fi

# Get & set the instance's public IP address
PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/public-ipv4)
if [ -z "$PUBLIC_IP" ]; then
  log "Failed to get public IP address"
  exit 1
fi
log "Retrieved public IP: $PUBLIC_IP"

# Create JSON payload for Cloudflare
CHANGE_BATCH1=$(cat <<EOF
{
  "type": "A",
  "name": "$RECORD_NAME1",
  "content": "$PUBLIC_IP",
  "ttl": 300,
  "proxied": true
}
EOF
)

CHANGE_BATCH2=$(cat <<EOF
{
  "type": "A",
  "name": "$RECORD_NAME2",
  "content": "$PUBLIC_IP",
  "ttl": 300,
  "proxied": true
}
EOF
)

log "Updating DNS records for $RECORD_NAME1 and $RECORD_NAME2"

# Update Cloudflare DNS records
RESPONSE1=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID1" \
     -H "Authorization: Bearer $CF_API_TOKEN" \
     -H "Content-Type: application/json" \
     --data "$CHANGE_BATCH1")

HTTP_CODE1=$(echo "$RESPONSE1" | jq -r '.success')
ERROR_MESSAGE1=$(echo "$RESPONSE1" | jq -r '.errors[0].message')
if [ "$HTTP_CODE1" != "true" ]; then
    if [ "$ERROR_MESSAGE1" == "A record with the same settings already exists." ]; then
        log "DNS record for $RECORD_NAME1 is already up-to-date."
    else
        log "Failed to update DNS record for $RECORD_NAME1. Response: $RESPONSE1"
    fi
else
    log "Successfully updated DNS record for $RECORD_NAME1."
fi

RESPONSE2=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID2" \
     -H "Authorization: Bearer $CF_API_TOKEN" \
     -H "Content-Type: application/json" \
     --data "$CHANGE_BATCH2")

HTTP_CODE2=$(echo "$RESPONSE2" | jq -r '.success')
ERROR_MESSAGE2=$(echo "$RESPONSE2" | jq -r '.errors[0].message')
if [ "$HTTP_CODE2" != "true" ]; then
    if [ "$ERROR_MESSAGE2" == "A record with the same settings already exists." ]; then
        log "DNS record for $RECORD_NAME2 is already up-to-date."
    else
        log "Failed to update DNS record for $RECORD_NAME2. Response: $RESPONSE2"
    fi
else
    log "Successfully updated DNS record for $RECORD_NAME2."
fi

log "DNS update script completed."