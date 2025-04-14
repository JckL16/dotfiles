#!/bin/bash

# Always enable all connected outputs
for output in $(xrandr | grep " connected" | cut -d" " -f1); do
    xrandr --output "$output" --auto
done
