# welcome — a cozy dashboard for your terminal

A small Python program that prints a greeting, the time, the weather, and a few
stock/crypto prices every time you open a terminal. Catppuccin-themed, **no API
keys**, one dependency (`rich`), and cached so your shell still opens instantly.

```
                          __  __              ___              __
                         / / / /__  __  __   /   |  ____  ____/ /_______ _      __
                        / /_/ / _ \/ / / /  / /| | / __ \/ __  / ___/ _ \ | /| / /
                        / __  /  __/ /_/ /  / ___ |/ / / / /_/ / /  /  __/ |/ |/ /
                      /_/ /_/\___/\__, /  /_/  |_/_/ /_/\__,_/_/   \___/|__/|__/
                                 /____/

                           Good afternoon — your shell is ready when you are.

╭────────────  Clock ────────────╮ ╭─────── Atlanta, Georgia ───────╮ ╭───────────  Markets ───────────╮
│            2:23 PM             │ │              81°F              │ │     AAPL  $231.44  ▲ 0.82%     │
│     Thursday, September 17     │ │         Partly cloudy          │ │     NVDA  $178.12  ▼ 1.35%     │
│         Week 38 · EDT          │ │    H 88°  L 69°  feels 85°     │ │     BTC   $97,231  ▲ 2.41%     │
│           up 4h 12m            │ │     62% humidity · 7 mph       │ │     ETH    $3,713  ▼ 0.63%     │
╰────────────────────────────────╯ ╰─────────────────────── 4m ago ─╯ ╰─────────────────────── 1m ago ─╯
```

## Files

| Path | What |
|---|---|
| `welcome` | the program (Python 3.11+, needs `rich`; `pyfiglet` or `figlet` optional for the big greeting) |
| `config.example.toml` | every config key, commented — `welcome --init` writes the same thing to `~/.config/welcome/config.toml` |
| `systemd/` | user service + timer that runs `welcome --prefetch` every 5 minutes |
| `shell/welcome.zsh` | the snippet to put at the end of `~/.zshrc` / `~/.bashrc` |
| `install.sh` | symlinks `welcome` into `~/.local/bin`, writes the starter config, `--timer` enables the prefetch timer |
| `shell.nix` | `nix-shell` with all dependencies (NixOS / any nix user) |
| `welcome-terminal-dashboard.md` | the full spec and walkthrough — the source of truth |

## Quick start

```sh
# dependencies
sudo pacman -S --needed python python-rich figlet     # Arch / CachyOS
nix-shell                                             # NixOS: temporary shell (see below for permanent)

./install.sh              # link into ~/.local/bin + starter config
$EDITOR ~/.config/welcome/config.toml
welcome                   # first run fetches; every run after is instant
./install.sh --timer      # optional: background prefetch, then set fetch_on_launch = false
```

Then add the contents of `shell/welcome.zsh` to the end of your shell rc.

**NixOS, permanently** (`configuration.nix` or Home Manager):

```nix
environment.systemPackages = [        # or home.packages
  (pkgs.python3.withPackages (ps: with ps; [ rich pyfiglet ]))
  pkgs.figlet
];
```

## Flags

```
welcome              render the dashboard
welcome --refresh    ignore the cache this run
welcome --prefetch   refresh whatever is stale in the cache and exit silently (for a timer)
welcome --demo       render built-in sample data — no network, no cache
welcome --debug      show the real error instead of "unavailable"
welcome --init       write a starter config to ~/.config/welcome/config.toml
```

## Data sources (all keyless)

- Weather + geocoding: [Open-Meteo](https://open-meteo.com)
- Stocks, ETFs, indices: CNBC's quote service (`AAPL`, `SPY`, `.SPX`, `.IXIC`)
- Crypto: [CoinGecko](https://www.coingecko.com/en/api) simple-price

Each source is cached in `~/.cache/welcome/` with its own TTL. Stale data is
refetched in parallel with a 3 s timeout; if the refetch fails, the stale copy
is shown with its age in the card corner. No cache and no network → the card
says "unavailable" and the shell still opens.

## Acceptance checks

```sh
welcome --demo                                   # sample data; no network, no cache
COLUMNS=80  welcome --demo                       # cards stack vertically
COLUMNS=120 welcome --demo                       # three cards across
https_proxy=http://127.0.0.1:9 XDG_CACHE_HOME=$(mktemp -d) welcome
                                                 # offline + empty cache → "unavailable" cards, exit 0
welcome --debug                                  # a failing source shows its real traceback
time welcome --demo                              # ≈ 0.1 s
welcome --init                                   # writes the config, refuses to overwrite
NO_COLOR=1 welcome --demo                        # plain output
```
