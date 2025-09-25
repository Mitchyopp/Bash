#!/usr/bin/env bash

echo "--- Enter a commit message: ---"
read message
echo "--- Your commit message is: $message ---"

git add .
echo "'Git add .' Done successfully."
git commit -m "$message"
echo "--- Git commit done successfully ---"
git push origin main
echo "--- GIT PUSH DONE! ---"
