#!/bin/bash

echo "What's your name?"
read name

echo "Hiya $name"
sleep 0.5
echo "Hope your doing well $name"
notify-send "Hope your doing well $name"
