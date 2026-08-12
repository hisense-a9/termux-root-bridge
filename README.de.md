# termux-root-bridge

[English](README.md) · [Deutsch](README.de.md) · [Español](README.es.md)

Ein persistentes Ubuntu (via [proot-distro](https://github.com/termux/proot-distro)) in Termux auf dem Hisense A9 laufen lassen, per Widget starten/stoppen — und aus dieser Ubuntu-Session heraus **echte Android-Root-Befehle anfragen**, jeweils mit bewusster manueller Bestätigung.

Gedacht für alles, was in einer Termux/proot-Umgebung entwickelt/ausgeführt wird (z. B. AI-Coding-Agenten wie Claude Code), aber gelegentlich echten Geräte-Root braucht (Systemeinstellungen, `/sys`-Knoten, etc.).

## Warum nicht einfach `su` aus proot-distro heraus?

Funktioniert grundsätzlich nicht. `proot` fängt Systemaufrufe über `ptrace` ab; Magisks `su` kommuniziert intern mit dem `magiskd`-Daemon über einen eigenen RPC/Socket-Mechanismus. Zwei ptrace-artige Schichten übereinander kollidieren (`write failed: Broken pipe` bei einem direkten Testaufruf). Das ist eine architektonische Grenze von proot, keine Konfigurationsfrage.

## Architektur

```
Ubuntu-Session (proot-distro)          Außerhalb von proot (normales Termux)
────────────────────────────           ──────────────────────────────────────
androidsu "<befehl>"                   root-bridge-watch.sh (Hintergrund-Loop)
  schreibt Anfrage nach                  entdeckt neue Anfrage
  ~/.rootbridge/req-<id>.txt              │
  wartet auf Antwort                      ▼
                                        tmux display-popup
                                          → root-bridge-confirm.sh <id>
                                             zeigt Befehl an, read -t 10 "y"?
                                             ja  → su -c "<befehl>" (echtes Root)
                                             nein/Timeout → abgelehnt
                                             schreibt Ergebnis nach
                                             ~/.rootbridge/res-<id>.txt
  liest Antwort, gibt Exitcode+Ausgabe
  zurück
```

`su` wird ausschließlich außerhalb von proot aufgerufen — nie innerhalb. Der Client (`androidsu`, läuft in proot) tut nichts Privilegiertes, nur Datei-I/O; die gesamte Rechte-Eskalation passiert in einem Prozess, der nie unter proots ptrace steht.

**Wichtiger Grund für `tmux display-popup` statt eines zweiten tmux-Fensters:** Falls euer einziger Zugang ein Homescreen-Widget-Toggle ist (kein Fenster-Wechsel innerhalb von tmux möglich/praktikabel), erscheint die Bestätigung als Overlay **direkt über dem aktuell sichtbaren Fenster** — kein Wechseln nötig.

## Sicherheitsmodell

Keine neue Vertrauensgrenze: Alles, was in der Ubuntu-Session läuft, hat ohnehin volle Termux-App-Rechte. Neu ist nur die *zusätzliche*, pro Befehl manuell bestätigte Fähigkeit, echte Android-Root-Aktionen anzufragen — jede Anfrage zeigt den exakten Befehlstext, und nur eine bewusste `y`-Eingabe (nicht Enter/Leereingabe) löst die Ausführung aus. Timeout gilt als Ablehnung.

## Installation

Voraussetzungen: Termux, `proot-distro` mit installierter Ubuntu-Distro, `tmux` (≥ 3.2 für `display-popup`), Root (z. B. Magisk) mit Termux als zugelassene Superuser-App.

```sh
mkdir -p ~/bin ~/.shortcuts
cp scripts/ubuntu-toggle.sh scripts/androidsu scripts/root-bridge-watch.sh scripts/root-bridge-confirm.sh ~/bin/
chmod 700 ~/bin/ubuntu-toggle.sh ~/bin/androidsu ~/bin/root-bridge-watch.sh ~/bin/root-bridge-confirm.sh
cp ~/bin/ubuntu-toggle.sh "~/.shortcuts/Ubuntu Toggle"   # für Termux:Widget
```

In der proot-distro-Distro `androidsu` auf den PATH legen (Container-eigene `~/.bashrc`, nicht die von Termux):

```sh
echo 'export PATH="/data/data/com.termux/files/home/bin:$PATH"' >> ~/.bashrc
```

Termux:Widget installieren (z. B. von [GitHub](https://github.com/termux/termux-widget/releases) oder F-Droid — muss zur Signatur-Familie eurer Termux-Installation passen), Widget-Kachel `Ubuntu Toggle` auf den Homescreen legen.

**Hinweis:** Datei-Rechte/SELinux-Kontext müssen zur eigenen Termux-App-UID passen (`id -u` in Termux, SELinux-Kategorie via `ls -Z ~`) — die genauen Werte sind pro Installation unterschiedlich, hier nicht fest verdrahtet.

## Verwendung

```sh
# Auf dem Homescreen: Widget-Kachel "Ubuntu Toggle" antippen (startet/stoppt).
# In der Ubuntu-Session:
androidsu id
# → Popup erscheint, mit 'y' + Enter bestätigen (10s Zeitfenster)
# → uid=0(root) gid=0(root) ...
```

## Referenz / Inspiration

[hisense-a9/PatchingService](https://github.com/hisense-a9/PatchingService) zeigt, dass proot-übergreifende IPC zu einem Root-Prozess grundsätzlich funktioniert (dort: ein nativer Daemon auf einem abstrakten Unix-Socket für E-Ink-Steuerkommandos). Dieses Projekt nutzt aus Einfachheitsgründen Datei-Polling statt eines Sockets — für einen manuell bestätigten, gelegentlichen Anwendungsfall ist der Latenzunterschied irrelevant.
