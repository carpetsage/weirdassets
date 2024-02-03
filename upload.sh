#!/bin/bash
curl -X POST \
  -F file=@"$FILENAME" \
  -H "Authorization: Bearer $TOKEN" \
  --form "id=$FILENAME" \
  https://api.cloudflare.com/client/v4/accounts/$ACCOUNT/images/v1
