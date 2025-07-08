#!/bin/bash

text=$1
repeat=$2

for ((i = 0; i < repeat; i++)); do
  wtype "$text"
  sleep 0.2
done
