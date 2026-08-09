# Defense Swarm -- Dedicated Server

Host your own persistent **Defense Swarm** world: a co-op
tower-defense survival game for up to 6 pilots. This repo holds the
dedicated-server builds and the one-command installer -- the game
itself is developed in a separate (private) repository.

The server build is made with Godot's dedicated-server export:
textures and audio are stripped, so it runs light and headless.

## Install on a Linux VPS -- one command

```
curl -sSL https://raw.githubusercontent.com/TallblokeUK/defense-swarm-server/main/install.sh | sudo bash
```

That downloads the latest server release, installs it to
`/opt/defense-swarm`, creates a service user, sets up systemd
(auto-restart, starts on boot), opens the firewall if `ufw` is
present, starts the server, and prints your personal web-admin link:

```
 Web admin:   http://203.0.113.7:8080/?t=a1b2c3
 Players join: 203.0.113.7  (UDP 7777)
```

Open the link, set a join password, give friends the IP. Done.

If your provider has its own cloud firewall, also open **UDP 7777**
(game -- ENet is UDP, a TCP rule will not work) and **TCP 8080**
(web admin) there.

## The web admin page

Every server serves a private settings page on port 8080, protected
by a token printed at boot (and saved in `server.cfg`). It shows live
status -- uptime, pilots aboard, current wave, treasury, core health,
your join address -- and lets you change the join password and player
cap on the fly. Anyone with the tokened link can change settings, so
don't paste it in public.

## Config

`~swarm/.local/share/godot/app_userdata/Defense Swarm/server.cfg`
(auto-created on first boot):

```ini
[server]
port=7777          ; game port (UDP)
password=""        ; join password ("" = open server)
max_players=5      ; joining pilots (6 crew total on a home host)

[admin]
port=8080          ; web admin port (TCP)
token="a1b2c3"     ; admin key, auto-generated
```

CLI overrides: `--port=7777 --password=secret` (handy for containers).

## How saves work

The server owns the world (base, towers, tech, treasury, wave) and
stores it locally in `server_world.dat`: it checkpoints during calm,
whenever a pilot leaves, and resumes the same world across restarts --
pilots drop in and out and everything is where they left it. Each
player's ship and gear live in a per-world character file on their own
machine (Valheim style); rejoining restores their pilot automatically.
If the swarm breaches the core, the run ends for the whole crew: the
server opens a fresh world 8 seconds later.

## Manage it

```
systemctl status defense-swarm
journalctl -u defense-swarm -f
systemctl restart defense-swarm
```

## Manual install / other platforms

Grab a build from [Releases](https://github.com/TallblokeUK/defense-swarm-server/releases)
and run it anywhere:

```
./defense_swarm.x86_64 --headless -- --server
```

On Windows, put `start-server.bat` next to the game exe and
double-click it.
