#!/usr/bin/env bash

request() {
	timeout 1 nc 127.0.0.1 19444 <<< "$1" 2>/dev/null || true
}

get_server_info() {
	request '{"command":"serverinfo"}' |
		jq -c 'select(.success == true)'
}

refresh_waybar() {
	pkill -RTMIN+8 -x waybar 2>/dev/null || true
}

show_help() {
	printf '%s\n' \
		"Usage: $(basename "$0") [COMMAND]" \
		"" \
		"Control HyperHDR LEDs and effects for the Waybar module." \
		"" \
		"Commands:" \
		"  status         Print Waybar-compatible JSON (default)" \
		"  state          Print the current LED/effect state" \
		"  toggle         Toggle LED output on or off" \
		"  effect [NAME]  Stop the active effect, or select one with Rofi" \
		"                 When NAME is provided, start it without Rofi" \
		"  -h, --help     Show this help"
}

read_state() {
	local info led_state effect
	info="$(get_server_info)"
	if [[ -z "$info" ]]; then
		printf '%s\n' unavailable
		return
	fi

	led_state="$(jq -r '.info.components[]? | select(.name == "LEDDEVICE") | .enabled' <<< "$info")"
	effect="$(jq -r '[.info.priorities[]? | select(.priority == 100 and .componentId == "EFFECT")][0].owner // empty' <<< "$info")"

	if [[ "$led_state" == false ]]; then
		printf '%s\n' off
	elif [[ -n "$effect" ]]; then
		printf 'effect\t%s\n' "$effect"
	elif [[ "$led_state" == true ]]; then
		printf '%s\n' on
	else
		printf '%s\n' unavailable
	fi
}

render_status() {
	local state effect
	state="$(read_state)"

	case "$state" in
		on)
			jq -cn '{text:"", tooltip:"HyperHDR LEDs: on\nClick: turn off\nRight-click: select effect", class:"on"}'
			;;
		off)
			jq -cn '{text:"", tooltip:"HyperHDR LEDs: off\nClick: turn on\nRight-click: select effect", class:"off"}'
			;;
		effect$'\t'*)
			effect="${state#*$'\t'}"
			jq -cn --arg effect "$effect" '{text:"", tooltip:("HyperHDR effect: " + $effect + "\nClick: turn LEDs off\nRight-click: stop effect"), class:"effect"}'
			;;
		*)
			jq -cn '{text:"", tooltip:"HyperHDR is unavailable", class:"unavailable"}'
			;;
	esac
}

toggle_leds() {
	local state target reply info
	info="$(get_server_info)"
	state="$(jq -r '.info.components[]? | select(.name == "LEDDEVICE") | .enabled' <<< "$info")"

	case "$state" in
		true) target=false ;;
		false) target=true ;;
		*)
			notify-send -i dialog-warning "HyperHDR" "Could not read the LED state"
			return 1
			;;
	esac

	reply="$(request "{\"command\":\"componentstate\",\"componentstate\":{\"component\":\"LEDDEVICE\",\"state\":$target}}")"
	if ! jq -e '.success == true' >/dev/null 2>&1 <<< "$reply"; then
		notify-send -i dialog-warning "HyperHDR" "Could not change the LED state"
		return 1
	fi

	refresh_waybar
}

toggle_effect() {
	local requested_effect="${1:-}"
	local info active_effect selection payload reply
	info="$(get_server_info)"
	if [[ -z "$info" ]]; then
		notify-send -i dialog-warning "HyperHDR" "Could not read the available effects"
		return 1
	fi

	active_effect="$(jq -r '[.info.priorities[]? | select(.priority == 100 and .componentId == "EFFECT")][0].owner // empty' <<< "$info")"
	if [[ -n "$active_effect" ]]; then
		reply="$(request '{"command":"clear","priority":100}')"
	else
		if [[ -n "$requested_effect" ]]; then
			selection="$requested_effect"
		else
			selection="$(jq -r '.info.effects[]?.name' <<< "$info" | rofi -dmenu -i -p 'HyperHDR effect')"
		fi
		[[ -n "$selection" ]] || return 0

		request '{"command":"componentstate","componentstate":{"component":"LEDDEVICE","state":true}}' >/dev/null
		payload="$(jq -cn --arg effect "$selection" '{command:"effect", effect:{name:$effect}, priority:100, origin:"waybar"}')"
		reply="$(request "$payload")"
	fi

	if ! jq -e '.success == true' >/dev/null 2>&1 <<< "$reply"; then
		notify-send -i dialog-warning "HyperHDR" "Could not change the effect"
		return 1
	fi

	refresh_waybar
}

case "${1:-status}" in
	status) render_status ;;
	state) read_state ;;
	toggle) toggle_leds ;;
	effect) toggle_effect "${2:-}" ;;
	-h|--help) show_help ;;
	*)
		printf 'Unknown command: %s\n\n' "$1" >&2
		show_help >&2
		exit 2
		;;
esac
