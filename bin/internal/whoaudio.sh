#!/bin/zsh
# Print which processes currently hold an audio device (macOS).
#
# Two independent signals, because a process can hold a Bluetooth device open
# without streaming — which files no power assertion and so is invisible to pmset.

echo "== streaming (pmset assertions) =="
pmset -g assertions | awk '
  /com\.apple\.audio\..*context\.preventuseridlesleep/ {
    match($0, /com\.apple\.audio\.[^"]*/)
    dev = substr($0, RSTART + length("com.apple.audio."), RLENGTH - length("com.apple.audio."))
    sub(/\.context.*/, "", dev); next
  }
  /Created for PID:/ {
    gsub(/[^0-9]/, "", $NF); pid = $NF
    cmd = "ps -p " pid " -o comm= 2>/dev/null"; cmd | getline path; close(cmd)
    if (path == "") name = "(gone)"
    else { n = split(path, parts, "/"); name = parts[n] }
    printf "  %-26s  %-7s  %s\n", dev, pid, name
  }'

echo "== device open (CoreAudio clients) =="
lsof -c coreaudiod +c 0 2>/dev/null | awk '/AudioServerDriver|IOAudio/ {print "  " $1, $2}' | sort -u
lsof +c 0 2>/dev/null | awk '
  /CoreAudio\.component\/Contents\/MacOS\/CoreAudio/ && !seen[$2]++ {
    printf "  %-7s  %s\n", $2, $1
  }'
