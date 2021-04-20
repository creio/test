#!/usr/bin/env bash
# Fork
# Gist: https://gist.github.com/skylerwlewis/ba052db5fe26424255674931d43fc030
#
# Usage:
# ndns.sh <IPFS_HASH> <ACCESS_TOKEN>
#
# Example:
# ndns.sh QmdykiCNvE2vTSTmy5dmBf8 aCcEsStOKeN

ACCESS_TOKEN="${1:-$NETLIFY_TOKEN}"
IPFS_HASH="$2"
DOMAIN="ctlos.ru"
SUBDOMAIN="test"
TTL="60"

NETLIFY_API="https://api.netlify.com/api/v1"
CNAME_VALUE="dnslink=/ipfs/$IPFS_HASH"

HOSTNAME="_dnslink.$SUBDOMAIN.$DOMAIN"

DNS_ZONES_RESPONSE=$(curl -s "$NETLIFY_API/dns_zones?access_token=$ACCESS_TOKEN" --header "Content-Type:application/json")
ZONE_ID=$(echo $DNS_ZONES_RESPONSE | jq ".[]  | select(.name == \"$DOMAIN\") | .id" --raw-output)
DNS_RECORDS_RESPONSE=$(curl -s "$NETLIFY_API/dns_zones/$ZONE_ID/dns_records?access_token=$ACCESS_TOKEN" --header "Content-Type:application/json")
RECORD=$(echo $DNS_RECORDS_RESPONSE | jq ".[]  | select(.hostname == \"$HOSTNAME\")" --raw-output)
RECORD_VALUE=$(echo $RECORD | jq ".value" --raw-output)

if [[ "$#" -ne 2 ]]; then
  # echo "$RECORD_VALUE"
  echo ${RECORD_VALUE##*/}
  exit
else
  echo
fi

echo "Current $HOSTNAME value is $RECORD_VALUE"

if [[ "$RECORD_VALUE" != "$CNAME_VALUE" ]]; then

  if [[ "$RECORD_VALUE" != "" ]]; then
    echo "Deleting current entry for $HOSTNAME"
    RECORD_ID=$(echo $RECORD | jq ".id" --raw-output)
    DELETE_RESPONSE_CODE=$(curl -X DELETE -s -w "%{response_code}" "$NETLIFY_API/dns_zones/$ZONE_ID/dns_records/$RECORD_ID?access_token=$ACCESS_TOKEN" --header "Content-Type:application/json")

    if [[ $DELETE_RESPONSE_CODE != 204 ]]; then
      echo "There was a problem deleting the existing $HOSTNAME entry, response code was $DELETE_RESPONSE_CODE"
      exit
    fi
  fi

  echo "Creating new entry for $HOSTNAME with value $CNAME_VALUE"
  CREATE_BODY=$(jq -n --arg hostname "$HOSTNAME" --arg externalIp "$CNAME_VALUE" --arg ttl $TTL '
  {
      "type": "TXT",
      "hostname": $hostname,
      "value": $externalIp,
      "ttl": $ttl|tonumber
  }')

  CREATE_RESPONSE=$(curl -s --data "$CREATE_BODY" "$NETLIFY_API/dns_zones/$ZONE_ID/dns_records?access_token=$ACCESS_TOKEN" --header "Content-Type:application/json")

  NEW_RECORD_TYPE=$(echo $CREATE_RESPONSE | jq ".type" --raw-output)
  NEW_RECORD_HOSTNAME=$(echo $CREATE_RESPONSE | jq ".hostname" --raw-output)
  NEW_RECORD_VALUE=$(echo $CREATE_RESPONSE | jq ".value" --raw-output)
  NEW_RECORD_TTL=$(echo $CREATE_RESPONSE | jq ".ttl" --raw-output)

  if [[ $NEW_RECORD_TYPE != "TXT" ]] || [[ $NEW_RECORD_HOSTNAME != $HOSTNAME ]] || [[ $NEW_RECORD_VALUE != $CNAME_VALUE ]] || [[ $NEW_RECORD_TTL != $TTL ]]; then
    echo "There was a problem creating the new entry, some values did not match"
    exit
  fi
fi
