#!/bin/bash
# pomo.sh

echo "Please enter a time you'd like to focus for."
read WORK_MIN
echo "Please enter how long you want your break to be."
read BREAK_MIN

notify-send "🍅 Pomodoro Started" "$WORK_MIN minutes of work"
sleep "${WORK_MIN}m"
notify-send "☕ Break Time!" "$BREAK_MIN minutes"
sleep "${BREAK_MIN}m"
notify-send "✅ Pomodoro Complete"
