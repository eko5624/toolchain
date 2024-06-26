#!/bin/bash
set -ex
CURL_RETRIES="--connect-timeout 60 --retry 5 --retry-delay 5"

# Release assets
curl -u eko5624:$GH_TOKEN $CURL_RETRIES \
  -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/${GITHUB_REPOSITORY}/releases \
  -d '{"tag_name": "toolchain"}'
  
release_id=$(curl -u eko5624:$GH_TOKEN $CURL_RETRIES \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/${GITHUB_REPOSITORY}/releases/tags/toolchain | jq -r '.id')
  
for f in *.7z; do 
  curl -u eko5624:$GH_TOKEN $CURL_RETRIES \
    -X POST -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: $(file -b --mime-type $f)" \
    https://uploads.github.com/repos/${GITHUB_REPOSITORY}/releases/$release_id/assets?name=$(basename $f) \
    --data-binary @$f; 
done
