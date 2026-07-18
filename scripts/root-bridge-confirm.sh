#!/data/data/com.termux/files/usr/bin/bash
# Wird per `tmux display-popup` gestartet, $1 = Request-ID.
# Zeigt die Anfrage direkt im aktuell sichtbaren Fenster als Overlay an.

BRIDGE_DIR="$HOME/.rootbridge"
ID="$1"
REQ="$BRIDGE_DIR/req-$ID.txt"
RES="$BRIDGE_DIR/res-$ID.txt"
CMD="$(cat "$REQ" 2>/dev/null)"

ANSWER=""
read -t 10 -p "Root-Anfrage: $CMD — mit 'y' + Enter bestätigen (10s): " ANSWER

if [ "$ANSWER" = "y" ]; then
    OUTPUT="$(su -c "$CMD" 2>&1)"
    CODE=$?
    printf '%s\n%s\n' "$CODE" "$OUTPUT" > "$RES"
    echo "Ausgeführt (Exitcode $CODE)."
else
    printf '99\nAbgelehnt (kein y oder Timeout).\n' > "$RES"
    echo "Abgelehnt."
fi

sleep 2
rm -f "$REQ"
