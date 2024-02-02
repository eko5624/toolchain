#!/bin/bash
set -ex
CURL_RETRIES="--connect-timeout 60 --retry 5 --retry-delay 5"

# Delete assets
asset_id=($(curl -u $GITHUB_ACTOR:$GH_TOKEN $CURL_RETRIES \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/${GITHUB_REPOSITORY}/releases/tags/toolchain \
| jq -r '."assets"[] | select(.name | contains("'"$1"'")) | .id' | tr -d '\r'))  
  
curl -u $GITHUB_ACTOR:$GH_TOKEN $CURL_RETRIES \
  -X DELETE \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/${GITHUB_REPOSITORY}/releases/assets/$asset_id
