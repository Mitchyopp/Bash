#!/usr/bin/env bash

while true; do
    domain=$(shuf -n1 <<EOF
ads.google.com
tracking.facebook.net
doubleclick.net
sponsor.example.org
adserver.amazon.com
metrics.apple.com
popup.badsite.io
redirect.clickbait.biz
EOF
)
    echo "[BLOCKED] $(date '+%Y-%m-%d %H:%M:%S')  $domain"
    sleep 0.3
done
