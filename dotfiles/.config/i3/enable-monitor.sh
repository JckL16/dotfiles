#!/bin/bash

# Get the currently primary display, or fallback to the first connected one
PRIMARY=$(xrandr --query | awk '/ connected primary/ {print $1}')
if [ -z "$PRIMARY" ]; then
    PRIMARY=$(xrandr --query | awk '/ connected/ {print $1; exit}')
fi

# Step 1: Always turn on the primary display
xrandr --output "$PRIMARY" --auto --primary

# Step 2: Turn off all other displays
for output in $(xrandr | grep " connected" | cut -d" " -f1); do
    if [ "$output" != "$PRIMARY" ]; then
        xrandr --output "$output" --off
    fi
done

# Step 3: Turn on and arrange external monitors (to the right of primary)
for output in $(xrandr | grep " connected" | cut -d" " -f1); do
    if [ "$output" != "$PRIMARY" ]; then
        xrandr --output "$output" --auto --right-of "$PRIMARY"
    fi
done
