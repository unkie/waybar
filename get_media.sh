#!/usr/bin/zsh

player="$(playerctl -l)"
if [[ -z "$player" ]]; then
	echo "󰝛"
	exit
fi

if [[ $player == exaile* ]]; then
	player="󰝚"
elif [[ $player == chromium* ]]; then
	player=""
elif [[ $player == firefox* ]]; then
	player=""
elif [[ $player == mpv* ]]; then
	player="󰎁"
elif [[ $player == vlc* ]]; then
	player="󰎁"
else
	player=""
fi

player_status=$(playerctl status)
meta=$(playerctl metadata -f "{{artist}}::{{album}}::{{title}}::{{duration(position)}}::{{duration(mpris:length)}}")
meta=("${(@s/::/)meta}")

truncate() {
	if (( "${#1}" > "$2" )); then
		echo "${1:0:$2}$3"
	else
		echo "$1"
	fi
}

artist=$(truncate "$meta[1]" 16 ...)
album=$(truncate "$meta[2]" 16 ...)
title=$(truncate "$meta[3]" 48 ...)
duration=$meta[4]
position=$meta[5]

if [[ $player_status = "Playing" ]]; then
    song_status=''
elif [[ $player_status = "Paused" ]]; then
    song_status=''
elif [[ $player_status = "Stopped" ]]; then
    song_status=''
	progress=''
else
    song_status=''
	artist='error reading player status'
	album=''
	title=''
	duration=''
	position=''
fi

append() {
	if [[ "$1" == *[] ]]; then
		1+=" $2"
	else
		1+=" - $2"
	fi
	echo $1
}

playing="${player}  ${song_status}"
if [[ -n "$artist" ]]; then playing=$(append "$playing" $artist); fi
if [[ -n "$album" ]]; then playing=$(append "$playing" $album); fi
if [[ -n "$title" ]]; then playing=$(append "$playing" $title); fi

echo "$playing"


