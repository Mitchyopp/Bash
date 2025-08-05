#!/bin/bash

# ========== 🔐 Root Check ==========
if [[ $EUID -ne 0 ]]; then
  echo "❌ This script must be run as root (sudo)."
  exit 1
fi

# ========== 🎮 Welcome ==========
echo "🎮 Ydotool AutoClicker/KeyPresser"
echo "Choose an action:"
echo "  - '1' or 'left'      → Left Mouse Click"
echo "  - '2' or 'middle'    → Middle Mouse Click"
echo "  - '3' or 'right'     → Right Mouse Click"
echo "  - key like 'f', 'enter', 'space', etc."

read -rp "🧠 Enter your choice: " input
input=$(echo "$input" | tr '[:upper:]' '[:lower:]')

# ========== 🎹 Keycode Lookup ==========
declare -A keycodes=(
  [a]=30 [b]=48 [c]=46 [d]=32 [e]=18 [f]=33 [g]=34 [h]=35
  [i]=23 [j]=36 [k]=37 [l]=38 [m]=50 [n]=49 [o]=24 [p]=25
  [q]=16 [r]=19 [s]=31 [t]=20 [u]=22 [v]=47 [w]=17 [x]=45
  [y]=21 [z]=44 [space]=57 [enter]=28 [tab]=15
)

# ========== 🧠 Determine Action ==========
if [[ "$input" == "1" || "$input" == "left" ]]; then
  action="click 0"
elif [[ "$input" == "2" || "$input" == "middle" ]]; then
  action="click 1"
elif [[ "$input" == "3" || "$input" == "right" ]]; then
  action="click 2"
elif [[ -n "${keycodes[$input]}" ]]; then
  code="${keycodes[$input]}"
  action="key ${code}:1 ${code}:0"
else
  echo "❌ Unknown key or action: '$input'"
  echo "Tip: Only single characters or known keys like 'enter' or 'space' are supported."
  exit 1
fi

# ========== 🔢 Repeats ==========
read -rp "🔁 How many times should I repeat it? " count
if ! [[ "$count" =~ ^[0-9]+$ ]]; then
  echo "❌ Invalid number"
  exit 1
fi

# ========== ⏲️ Delays ==========
read -rp "🕒 Delay between actions (in seconds, e.g. 0.1): " delay
if ! [[ "$delay" =~ ^[0-9.]+$ ]]; then
  echo "❌ Invalid delay format"
  exit 1
fi

read -rp "⏳ Delay before starting (in seconds): " start_delay
if ! [[ "$start_delay" =~ ^[0-9]+$ ]]; then
  echo "❌ Invalid start delay"
  exit 1
fi

echo "⏳ Waiting $start_delay seconds before starting..."
sleep "$start_delay"

# ========== 🚀 GO ==========
echo "🚀 Running '$action' $count times with $delay sec delay..."
for ((i = 1; i <= count; i++)); do
  sudo ydotool $action
  sleep "$delay"
done

echo "✅ Done!"
