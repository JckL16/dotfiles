#!/bin/bash

# Trigger rofi dialog to confirm exit
response=$(rofi -dmenu -p "Exit i3?" -mesg "Are you sure you want to exit i3? This will end your X session." -show run -modi run:rofi -no-lines -yoffset 35 -lines 3)

# Check if the response is any of y, Y, yes, or Yes (case-insensitive)
if echo "$response" | grep -iqE "^(y|yes)$"; then
    i3-msg exit
fi
