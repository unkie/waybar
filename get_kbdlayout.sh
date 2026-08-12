#!/usr/bin/env zsh

echo -e $(hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .active_keymap')
