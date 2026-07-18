#!/data/data/com.termux/files/usr/bin/bash
# Root-Bridge-Wächter: läuft unsichtbar im Hintergrund (eigenes tmux-Fenster).
# Beobachtet ~/.rootbridge/req-*.txt und zeigt jede Anfrage als tmux-Popup
# direkt über dem aktuell sichtbaren Fenster an - kein Fenster-Wechsel nötig.

BRIDGE_DIR="$HOME/.rootbridge"
mkdir -p "$BRIDGE_DIR"

while true; do
    for REQ in "$BRIDGE_DIR"/req-*.txt; do
        [ -e "$REQ" ] || continue
        ID="$(basename "$REQ" .txt)"
        ID="${ID#req-}"
        tmux display-popup -t ubuntu -E -w 90% -h 40% "$HOME/bin/root-bridge-confirm.sh $ID"
    done
    sleep 1
done
