# Only one picker at a time, including while copying the result.
exec 9>"${XDG_RUNTIME_DIR:?}/screenshot.lock"
flock -n 9 || exit 0

monitors=$(hyprctl -j monitors)
clients=$(hyprctl -j clients)

# Special workspaces cover the normal workspace. Never offer off-workspace or
# unmapped windows, even though Hyprland retains their geometry in `clients`.
boxes=$(jq -nr --argjson monitors "$monitors" --argjson clients "$clients" '
  $monitors[] as $monitor
  | (if $monitor.specialWorkspace.id != 0 then $monitor.specialWorkspace.id
     else $monitor.activeWorkspace.id end) as $workspace
  | $clients[]
  | select(.mapped and (.hidden | not) and .monitor == $monitor.id)
  | select(.workspace.id == $workspace or
      (.pinned and $monitor.specialWorkspace.id == 0))
  | select(.size[0] > 0 and .size[1] > 0)
  | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
')

# Slurp picks the smallest hovered box; output rectangles cover the gaps.
if ! geometry=$(printf '%s\n' "$boxes" | slurp -r -o \
    -b 00000026 -B 00000026 -s 00000000 -c "$SCREENSHOT_BORDER" -w 2); then
  exit 0 # Escape cancels without creating a file or changing the clipboard.
fi

umask 077
mkdir -p "$SCREENSHOT_DIRECTORY"
file=$(mktemp "$SCREENSHOT_DIRECTORY/screenshot-$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX.png")
if ! grim -g "$geometry" "$file"; then
  rm -f "$file"
  exit 1
fi
# The detached clipboard owner must not inherit the picker lock.
wl-copy --type image/png < "$file" 9>&-
