#!/usr/bin/env bash

read -rp "Enter your input: " input
echo "Your input is: $input"
read -rp "Would you like me to notify you on the output at well? (yes/no): " notify
if [ "$notify" = "yes" ]; then
	notify-send "$input"
fi
