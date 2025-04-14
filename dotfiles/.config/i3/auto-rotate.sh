#!/bin/bash

# Set your internal display name
DISPLAY_OUTPUT="eDP-1"

# Input device names from `xinput`
STYLUS="WCOM016C:00 2D1F:0151 Stylus stylus"
ERASER="WCOM016C:00 2D1F:0151 Stylus eraser"
# Your touchscreen device name (replace if different)
TOUCHSCREEN="ELAN902C:00 04F3:406B"

# Coordinate Transformation Matrices
normal="1 0 0 0 1 0 0 0 1"
left="0 -1 1 1 0 0 0 0 1"
right="0 1 0 -1 0 1 0 0 1"
inverted="-1 0 1 0 -1 1 0 0 1"

# Rotate inputs function
rotate_inputs() {
    MATRIX=$1
    # Stylus and eraser rotation
    xinput set-prop "$STYLUS" "Coordinate Transformation Matrix" $MATRIX
    xinput set-prop "$ERASER" "Coordinate Transformation Matrix" $MATRIX
    # Touchscreen rotation (via libinput and transformation matrix)
    xinput set-prop "$TOUCHSCREEN" "Coordinate Transformation Matrix" $MATRIX
    # Rotate the touchscreen via libinput (angle setting)
    case "$MATRIX" in
        "$normal") xinput set-prop "$TOUCHSCREEN" "libinput Rotation Angle" 0 ;;
        "$left") xinput set-prop "$TOUCHSCREEN" "libinput Rotation Angle" 90 ;;
        "$right") xinput set-prop "$TOUCHSCREEN" "libinput Rotation Angle" 270 ;;
        "$inverted") xinput set-prop "$TOUCHSCREEN" "libinput Rotation Angle" 180 ;;
    esac
}

# Listen to orientation events
monitor-sensor | while read -r line; do
    case "$line" in
        *normal*)
            xrandr --output $DISPLAY_OUTPUT --rotate normal
            rotate_inputs "$normal"
            ;;
        *left*)
            xrandr --output $DISPLAY_OUTPUT --rotate left
            rotate_inputs "$left"
            ;;
        *right*)
            xrandr --output $DISPLAY_OUTPUT --rotate right
            rotate_inputs "$right"
            ;;
        *inverted*|*bottom-up*)
            xrandr --output $DISPLAY_OUTPUT --rotate inverted
            rotate_inputs "$inverted"
            ;;
    esac
done

