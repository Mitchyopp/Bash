#!/usr/bin/env bash

echo "Please enter a commit message"

read message

git add .
git commit -m "$message"
git push origin main

echo "Done."
