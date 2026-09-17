# `welcome` — a cozy dashboard for your terminal

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
│                                │ │                                │ │                                │
│            2:23 PM             │ │              81°F              │ │     AAPL  $231.44  ▲ 0.82%     │
│     Thursday, September 17     │ │         Partly cloudy          │ │     NVDA  $178.12  ▼ 1.35%     │
│         Week 38 · EDT          │ │    H 88°  L 69°  feels 85°     │ │     BTC   $97,231  ▲ 2.41%     │
│                                │ │     62% humidity · 7 mph       │ │     ETH    $3,713  ▼ 0.63%     │
│           up 4h 12m            │ │                                │ │                                │
│                                │ │                                │ │                                │
╰────────────────────────────────╯ ╰─────────────────────── 4m ago ─╯ ╰─────────────────────── 1m ago ─╯
────────────────────────────────────────────────────────────────────────────────────────────────────────
```

(The greeting is a color gradient; the icons are Nerd Font glyphs and show as
boxes in a viewer without one. The "4m ago" corner tells you how old the data is.)

## Spec — read this first

**Goal.** A command `welcome` that renders the dashboard above from a TOML
config, in well under half a second, and never blocks or crashes the shell
because a website is slow or down.

**Non-goals.** No TUI/event loop (it prints and exits), no API keys, no
virtualenv unless explicitly asked, no dependencies beyond `rich` (+ optional
`pyfiglet`/`figlet` for the big greeting).

**Acceptance checks** — all of these must pass:

```sh
welcome --demo                                   # renders sample data; no network, no cache
COLUMNS=80  welcome --demo                       # cards stack vertically
COLUMNS=120 welcome --demo                       # three cards across
https_proxy=http://127.0.0.1:9 XDG_CACHE_HOME=$(mktemp -d) welcome
                                                 # offline + empty cache → "unavailable" cards, exit 0
welcome --debug                                  # a failing source shows its real traceback
time welcome --demo                              # ≈ 0.15 s
welcome --init                                   # writes ~/.config/welcome/config.toml, refuses to overwrite
NO_COLOR=1 welcome --demo                        # plain output (rich honours NO_COLOR for free)
```

## How it's put together

| Piece | Choice | Why |
|---|---|---|
| Language | Python 3.11+ | `tomllib` is built in; quick to tweak |
| Rendering | [`rich`](https://github.com/Textualize/rich) | panels, tables, hex colors, no curses pain |
| HTTP | `urllib` (stdlib) | three GETs don't need `requests`; saves a package and ~50 ms of import |
| Big greeting | `pyfiglet` → `figlet` binary → plain text | first one found wins |
| Weather | [Open-Meteo](https://open-meteo.com) | free, keyless, geocodes "city name" for you |
| Stocks | [CNBC](https://www.cnbc.com/quotes/AAPL) quote service | free, keyless, many symbols per call, includes previous close (Stooq's CSV endpoint went behind a JS challenge in 2026) |
| Crypto | [CoinGecko](https://www.coingecko.com/en/api) simple-price | free, keyless, includes 24h change |
| Speed | JSON cache in `~/.cache/welcome/` | warm start ≈ 0.15 s; network only when something is stale |

**How the cache behaves.** Each source (geocode, weather, stocks, crypto) has
its own file and its own TTL. Fresh → used as-is. Stale → refetched, in
parallel, with a 3 s socket timeout. Refetch failed (or the source returned
nothing) → the stale copy is shown with its age in the card corner. No cache and
no network → the card says "unavailable". Changing a city or ticker changes the
file name, so edits take effect immediately.

**Two ways to run it.** Out of the box, `welcome` refreshes stale data itself
on launch. Section 6 shows the nicer setup: a systemd user timer runs
`welcome --prefetch` every five minutes and the launch-time `welcome` never
touches the network at all.

Files:

```
~/.local/bin/welcome              # the program
~/.config/welcome/config.toml     # your settings (welcome --init writes a starter)
~/.cache/welcome/*.json           # created automatically
```

## 1. Install the dependencies

**CachyOS / Arch**

```sh
sudo pacman -S --needed python python-rich figlet   # figlet is optional: big greeting
paru -S python-pyfiglet                             # optional alternative with many more fonts (AUR)
```

**Any distro, no system packages (uv)** — skip the packages above, add this
header as the *first lines* of the script in step 3, and change its shebang to
`#!/usr/bin/env -S uv run --script --quiet`:

```python
# /// script
# requires-python = ">=3.11"
# dependencies = ["rich", "pyfiglet"]
# ///
```

**NixOS (Home Manager)**

```nix
home.packages = [
  (pkgs.python3.withPackages (ps: with ps; [ rich pyfiglet ]))
  pkgs.figlet
];
```

## 2. Create the config

```sh
welcome --init          # after step 3–4; or create the file by hand now
```

It writes `~/.config/welcome/config.toml` with every key present and commented.
Every key is optional — anything you delete falls back to the script's default.

```toml
# ~/.config/welcome/config.toml — every key is optional

name     = "Andrew"
greeting = "Hey {name}"          # rendered big; {name} is substituted
font     = "slant"               # any pyfiglet / figlet font
taglines = ["the terminal missed you.", "let's build something today.", "coffee first, then commits."]

cards = ["clock", "weather", "markets"]   # which cards, in which order

# clock
time_format = "%-I:%M %p"        # "%H:%M" for 24-hour
date_format = "%A, %B %-d"
uptime = true

# weather
city  = "Atlanta"                # geocoded once, then cached for 30 days
# lat = 33.75                    # set both to skip geocoding; city is then just the label
# lon = -84.39
units = "fahrenheit"             # or "celsius"

# markets
stocks = ["AAPL", "NVDA"]        # tickers CNBC knows: AAPL, SPY; indices start with a dot: ".SPX", ".IXIC"
fetch_on_launch = true           # false once a timer runs `welcome --prefetch` for you (section 6)

[crypto]                         # CoinGecko id (from the coin's URL) = label to show
bitcoin  = "BTC"
ethereum = "ETH"

[theme]
flavor   = "mocha"               # mocha | macchiato | frappe | latte
icons    = "nerd"                # nerd (needs a Nerd Font) | emoji
border   = "rounded"             # rounded | heavy | double | square | ascii
gradient = ["mauve", "pink", "flamingo", "peach", "yellow", "green", "teal", "sky", "blue", "lavender"]

[cache_minutes]
weather = 15
markets = 5
geocode = 43200                  # 30 days
```

## 3. Write the script

Save this as `~/.local/bin/welcome` (no extension — it's a command).

```python
#!/usr/bin/env python3
"""
welcome — a cozy little dashboard for your terminal.

Greeting · clock · weather · markets, in Catppuccin. No API keys; stdlib + rich.
Everything is cached so shell startup stays instant.

  welcome              render the dashboard
  welcome --refresh    ignore the cache this run
  welcome --prefetch   refresh whatever is stale in the cache and exit silently (for a timer)
  welcome --demo       render built-in sample data — no network, no cache
  welcome --debug      show the real error instead of "unavailable"
  welcome --init       write a starter config to ~/.config/welcome/config.toml
"""
from __future__ import annotations

import json
import math
import os
import random
import re
import subprocess
import sys
import time
import tomllib
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path

from rich import box
from rich.align import Align
from rich.console import Console, Group
from rich.panel import Panel
from rich.rule import Rule
from rich.table import Table
from rich.text import Text

# ── flags & paths ────────────────────────────────────────────────────────────
ARGS = set(sys.argv[1:])
REFRESH, PREFETCH, DEMO, DEBUG, INIT = (f"--{f}" in ARGS for f in ("refresh", "prefetch", "demo", "debug", "init"))
CONFIG_PATH = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "welcome" / "config.toml"
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "welcome"
TIMEOUT = 3                                 # socket timeout per request, seconds
HEADERS = {"User-Agent": "welcome-dashboard/2.0"}

# ── palettes (Catppuccin) ────────────────────────────────────────────────────
PALETTES = {
    "mocha": dict(rosewater="#f5e0dc", flamingo="#f2cdcd", pink="#f5c2e7", mauve="#cba6f7", red="#f38ba8",
                  maroon="#eba0ac", peach="#fab387", yellow="#f9e2af", green="#a6e3a1", teal="#94e2d5",
                  sky="#89dceb", sapphire="#74c7ec", blue="#89b4fa", lavender="#b4befe",
                  text="#cdd6f4", subtext="#a6adc8", overlay="#6c7086", surface="#45475a"),
    "macchiato": dict(rosewater="#f4dbd6", flamingo="#f0c6c6", pink="#f5bde6", mauve="#c6a0f6", red="#ed8796",
                      maroon="#ee99a0", peach="#f5a97f", yellow="#eed49f", green="#a6da95", teal="#8bd5ca",
                      sky="#91d7e3", sapphire="#7dc4e4", blue="#8aadf4", lavender="#b7bdf8",
                      text="#cad3f5", subtext="#a5adcb", overlay="#6e738d", surface="#494d64"),
    "frappe": dict(rosewater="#f2d5cf", flamingo="#eebebe", pink="#f4b8e4", mauve="#ca9ee6", red="#e78284",
                   maroon="#ea999c", peach="#ef9f76", yellow="#e5c890", green="#a6d189", teal="#81c8be",
                   sky="#99d1db", sapphire="#85c1dc", blue="#8caaee", lavender="#babbf1",
                   text="#c6d0f5", subtext="#a5adce", overlay="#737994", surface="#51576d"),
    "latte": dict(rosewater="#dc8a78", flamingo="#dd7878", pink="#ea76cb", mauve="#8839ef", red="#d20f39",
                  maroon="#e64553", peach="#fe640b", yellow="#df8e1d", green="#40a02b", teal="#179299",
                  sky="#04a5e5", sapphire="#209fb5", blue="#1e66f5", lavender="#7287fd",
                  text="#4c4f69", subtext="#6c6f85", overlay="#9ca0b0", surface="#bcc0cc"),
}
BORDERS = {"rounded": box.ROUNDED, "heavy": box.HEAVY, "double": box.DOUBLE,
           "square": box.SQUARE, "ascii": box.ASCII}

# ── defaults (every config key is optional) ──────────────────────────────────
DEFAULTS = {
    "name": os.environ.get("USER", "friend"),
    "greeting": "Hey {name}",
    "font": "slant",
    "taglines": ["the terminal missed you.", "let's build something today.", "coffee first, then commits.",
                 "one small step at a time.", "hope you slept well.", "your shell is ready when you are."],
    "cards": ["clock", "weather", "markets"],
    "time_format": "%-I:%M %p",
    "date_format": "%A, %B %-d",
    "uptime": True,
    "city": "Atlanta",
    "units": "fahrenheit",
    "stocks": ["AAPL", "NVDA"],
    "crypto": {"bitcoin": "BTC", "ethereum": "ETH"},
    "fetch_on_launch": True,
    "theme": {"flavor": "mocha", "icons": "nerd", "border": "rounded",
              "gradient": ["mauve", "pink", "flamingo", "peach", "yellow", "green", "teal", "sky", "blue", "lavender"]},
    "cache_minutes": {"weather": 15, "markets": 5, "geocode": 43200},
}

SAMPLE_CONFIG = '''# ~/.config/welcome/config.toml — every key is optional

name     = "__USER__"
greeting = "Hey {name}"          # rendered big; {name} is substituted
font     = "slant"               # any pyfiglet / figlet font
taglines = ["the terminal missed you.", "let's build something today.", "coffee first, then commits."]

cards = ["clock", "weather", "markets"]   # which cards, in which order

# clock
time_format = "%-I:%M %p"        # "%H:%M" for 24-hour
date_format = "%A, %B %-d"
uptime = true

# weather
city  = "Atlanta"                # geocoded once, then cached for 30 days
# lat = 33.75                    # set both to skip geocoding; city is then just the label
# lon = -84.39
units = "fahrenheit"             # or "celsius"

# markets
stocks = ["AAPL", "NVDA"]        # tickers CNBC knows: AAPL, SPY; indices start with a dot: ".SPX", ".IXIC"
fetch_on_launch = true           # false once a timer runs `welcome --prefetch` for you

[crypto]                         # CoinGecko id (from the coin's URL) = label to show
bitcoin  = "BTC"
ethereum = "ETH"

[theme]
flavor   = "mocha"               # mocha | macchiato | frappe | latte
icons    = "nerd"                # nerd (needs a Nerd Font) | emoji
border   = "rounded"             # rounded | heavy | double | square | ascii
gradient = ["mauve", "pink", "flamingo", "peach", "yellow", "green", "teal", "sky", "blue", "lavender"]

[cache_minutes]
weather = 15
markets = 5
geocode = 43200                  # 30 days
'''

ICONS = {
    "nerd": {"clear": "", "night_clear": "", "cloud": "", "night_cloud": "", "overcast": "",
             "fog": "", "drizzle": "", "rain": "", "snow": "", "storm": "", "clock": "", "chart": ""},
    "emoji": {"clear": "☀", "night_clear": "🌙", "cloud": "⛅", "night_cloud": "☁", "overcast": "☁",
              "fog": "🌫", "drizzle": "🌦", "rain": "🌧", "snow": "❄", "storm": "⛈", "clock": "🕒", "chart": "📈"},
}
# terminals disagree on the width of emoji + variation selector, so never emit U+FE0F
ICONS["emoji"] = {k: v.replace("\ufe0f", "") for k, v in ICONS["emoji"].items()}

# WMO weather codes (what Open-Meteo returns) → (icon key, description)
WMO = {
    0: ("clear", "Clear sky"), 1: ("clear", "Mostly clear"), 2: ("cloud", "Partly cloudy"),
    3: ("overcast", "Overcast"), 45: ("fog", "Fog"), 48: ("fog", "Rime fog"),
    51: ("drizzle", "Light drizzle"), 53: ("drizzle", "Drizzle"), 55: ("drizzle", "Heavy drizzle"),
    61: ("rain", "Light rain"), 63: ("rain", "Rain"), 65: ("rain", "Heavy rain"),
    71: ("snow", "Light snow"), 73: ("snow", "Snow"), 75: ("snow", "Heavy snow"),
    80: ("rain", "Showers"), 81: ("rain", "Showers"), 82: ("rain", "Heavy showers"),
    95: ("storm", "Thunderstorm"), 96: ("storm", "Thunderstorm"), 99: ("storm", "Thunderstorm"),
}

DEMO_DATA = {
    "weather": ({"place": "Atlanta, Georgia", "temp": 81.3, "feels": 85.0, "humidity": 62, "wind": 7.2,
                 "code": 2, "is_day": 1, "hi": 88.1, "lo": 69.4}, 240.0),
    "stocks": ([{"sym": "AAPL", "price": 231.44, "change": 0.82},
                {"sym": "NVDA", "price": 178.12, "change": -1.35}], 60.0),
    "crypto": ([{"sym": "BTC", "price": 97231.0, "change": 2.41},
                {"sym": "ETH", "price": 3712.55, "change": -0.63}], 60.0),
}


# ── config & cache ───────────────────────────────────────────────────────────
def load_config() -> dict:
    user: dict = {}
    if CONFIG_PATH.exists():
        with CONFIG_PATH.open("rb") as f:
            user = tomllib.load(f)
    cfg = {**DEFAULTS, **user}
    for section in ("theme", "cache_minutes"):          # shallow-merge the tables
        cfg[section] = {**DEFAULTS[section], **user.get(section, {})}
    return cfg


def init_config() -> None:
    if CONFIG_PATH.exists():
        print(f"config already exists: {CONFIG_PATH}")
        return
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    CONFIG_PATH.write_text(SAMPLE_CONFIG.replace("__USER__", os.environ.get("USER", "friend")))
    print(f"wrote {CONFIG_PATH} — set your name, city and tickers, then run `welcome`")


def slug(parts) -> str:
    """Config values → safe, readable cache-file name (so changing tickers changes the key)."""
    return re.sub(r"[^a-z0-9]+", "_", "-".join(str(p).lower() for p in parts)).strip("_")


def cached(key: str, ttl_minutes: float, fetch, allow_fetch: bool = True) -> tuple:
    """Return (data, age_seconds). Fresh cache → use it. Stale → refetch (if allowed).
    Refetch failed or not allowed → the stale copy, or (None, None) if there is none."""
    path = CACHE_DIR / f"{key}.json"
    data, age = None, None
    if path.exists():
        try:
            data, age = json.loads(path.read_text()), time.time() - path.stat().st_mtime
        except (json.JSONDecodeError, OSError):
            pass
    fresh = age is not None and age < ttl_minutes * 60
    if data is not None and fresh and not REFRESH:
        return data, age
    if not allow_fetch:
        return data, age
    try:
        new = fetch()
    except Exception:
        if DEBUG:
            raise
        return data, age
    try:                                    # a read-only cache dir must not cost us fresh data
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(new))
    except OSError:
        pass
    return new, 0.0


# ── HTTP (stdlib) ────────────────────────────────────────────────────────────
def get_text(url: str, params: dict | None = None) -> str:
    if params:
        url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params)
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=TIMEOUT) as r:
        return r.read().decode("utf-8", "replace")


def get_json(url: str, params: dict | None = None):
    return json.loads(get_text(url, params))


# ── data sources (all keyless) ───────────────────────────────────────────────
def geocode(city: str) -> dict:
    hits = get_json("https://geocoding-api.open-meteo.com/v1/search", {"name": city, "count": 1}).get("results")
    if not hits:
        raise LookupError(f"Open-Meteo knows no place called {city!r}")
    h = hits[0]
    return {"lat": h["latitude"], "lon": h["longitude"],
            "place": f"{h['name']}, {h.get('admin1') or h.get('country', '')}"}


def fetch_weather(loc: dict, units: str) -> dict:
    wx = get_json("https://api.open-meteo.com/v1/forecast", {
        "latitude": loc["lat"], "longitude": loc["lon"],
        "current": "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day",
        "daily": "temperature_2m_max,temperature_2m_min",
        "temperature_unit": units, "wind_speed_unit": "mph" if units == "fahrenheit" else "kmh",
        "timezone": "auto", "forecast_days": 1,
    })
    cur, day = wx["current"], wx["daily"]
    return {"temp": cur["temperature_2m"], "feels": cur["apparent_temperature"],
            "humidity": cur["relative_humidity_2m"], "wind": cur["wind_speed_10m"],
            "code": cur["weather_code"], "is_day": cur["is_day"],
            "hi": day["temperature_2m_max"][0], "lo": day["temperature_2m_min"][0]}


def fetch_stocks(stocks: list[str]) -> list[dict]:
    """CNBC's public quote service: many symbols per call, includes the previous close.
    Stocks and ETFs are plain tickers (AAPL, SPY); indices start with a dot (.SPX, .IXIC, .DJI)."""
    r = get_json("https://quote.cnbc.com/quote-html-webservice/restQuote/symbolType/symbol",
                 {"symbols": "|".join(s.upper() for s in stocks), "requestMethod": "itv",
                  "noform": "1", "partnerId": "2", "fund": "1", "exthrs": "1", "output": "json"})
    quotes = r.get("FormattedQuoteResult", {}).get("FormattedQuote", [])
    quotes = quotes if isinstance(quotes, list) else [quotes]
    out = []
    for q in quotes:
        try:
            last = float(str(q["last"]).replace(",", ""))
            prev = float(str(q["previous_day_closing"]).replace(",", ""))
        except (ValueError, KeyError, TypeError):
            continue                        # code != 0 — CNBC has no data for that symbol
        out.append({"sym": q["symbol"].lstrip("."), "price": last,
                    "change": (last - prev) / prev * 100 if prev else 0.0})
    if not out:                             # error page or all unknown: keep the old cache instead
        raise RuntimeError("CNBC returned no quotes")
    return out


def fetch_crypto(crypto: dict[str, str]) -> list[dict]:
    r = get_json("https://api.coingecko.com/api/v3/simple/price",
                 {"ids": ",".join(crypto), "vs_currencies": "usd", "include_24hr_change": "true"})
    out = [{"sym": ticker, "price": r[cid]["usd"], "change": r[cid].get("usd_24h_change") or 0.0}
           for cid, ticker in crypto.items() if cid in r]
    if not out:
        raise RuntimeError("CoinGecko returned no prices")
    return out


def weather_job(cfg: dict, allow: bool) -> tuple:
    ttl = cfg["cache_minutes"]
    if "lat" in cfg and "lon" in cfg:
        loc = {"lat": cfg["lat"], "lon": cfg["lon"], "place": cfg["city"]}
    else:
        loc, _ = cached("geo-" + slug([cfg["city"]]), ttl["geocode"], lambda: geocode(cfg["city"]), allow)
        if not loc:
            return None, None
    data, age = cached("weather-" + slug([cfg["city"], cfg["units"]]), ttl["weather"],
                       lambda: fetch_weather(loc, cfg["units"]), allow)
    return ({**data, "place": loc["place"]} if data else None), age


def gather(cfg: dict) -> dict:
    """Everything the selected cards need, as {name: (data, age)}. Sources run in parallel."""
    if DEMO:
        return DEMO_DATA
    allow = cfg["fetch_on_launch"] or REFRESH or PREFETCH   # a timer may own fetching
    ttl, cards = cfg["cache_minutes"], cfg["cards"]
    jobs = {}
    with ThreadPoolExecutor(max_workers=3) as pool:
        if "weather" in cards:
            jobs["weather"] = pool.submit(weather_job, cfg, allow)
        if "markets" in cards and cfg["stocks"]:
            jobs["stocks"] = pool.submit(cached, "stocks-" + slug(cfg["stocks"]), ttl["markets"],
                                         lambda: fetch_stocks(cfg["stocks"]), allow)
        if "markets" in cards and cfg["crypto"]:
            jobs["crypto"] = pool.submit(cached, "crypto-" + slug(cfg["crypto"]), ttl["markets"],
                                         lambda: fetch_crypto(cfg["crypto"]), allow)
        return {name: job.result() for name, job in jobs.items()}


# ── widgets ──────────────────────────────────────────────────────────────────
def age_str(age: float | None) -> str:
    if age is None:
        return ""
    m = int(age // 60)
    return "just now" if m < 1 else f"{m}m ago" if m < 60 else f"{m // 60}h ago"


def panel(ctx: dict, body, title: str, age: float | None = None) -> Panel:
    sub = f"[{ctx['pal']['overlay']}]{age_str(age)}" if age is not None else None
    return Panel(Align.center(body, vertical="middle"), title=title,
                 subtitle=sub, subtitle_align="right", **ctx["style"])


def big_text(text: str, font: str, width: int) -> str | None:
    try:
        import pyfiglet
        return pyfiglet.figlet_format(text, font=font, width=width)
    except Exception:                       # not installed, or unknown font
        pass
    try:                                    # the plain `figlet` binary works too
        r = subprocess.run(["figlet", "-f", font, "-w", str(width), text], capture_output=True, text=True)
        if r.returncode == 0:
            return r.stdout
    except OSError:
        pass
    return None


def header(ctx: dict) -> Group:
    cfg, pal, h = ctx["cfg"], ctx["pal"], ctx["now"].hour
    part = "morning" if 5 <= h < 12 else "afternoon" if h < 17 else "evening" if h < 22 else "night"
    greeting = cfg["greeting"].format(name=cfg["name"])
    grad = [pal[c] for c in cfg["theme"]["gradient"] if c in pal] or [pal["mauve"]]
    art = big_text(greeting, cfg["font"], ctx["width"])
    if art:
        big = Text()
        for i, line in enumerate(art.rstrip("\n").splitlines()):
            big.append(line + "\n", style=f"bold {grad[i % len(grad)]}")
    else:
        big = Text(f"✨  {greeting}!  ✨\n", style=f"bold {grad[0]}")
    tag = f" — {random.choice(cfg['taglines'])}" if cfg["taglines"] else ""
    sub = Text(f"Good {part}{tag}", style=f"italic {pal['subtext']}")
    return Group(Align.center(big), Align.center(sub))


def uptime() -> str | None:
    try:
        secs = float(Path("/proc/uptime").read_text().split()[0])
    except OSError:
        return None
    h, m = divmod(int(secs // 60), 60)
    d, h = divmod(h, 24)
    return (f"{d}d " if d else "") + f"{h}h {m:02d}m"


def clock_card(ctx: dict) -> Panel:
    cfg, pal, now = ctx["cfg"], ctx["pal"], ctx["now"]
    body = Text(justify="center")
    body.append(now.strftime(cfg["time_format"]) + "\n", style=f"bold {pal['peach']}")
    body.append(now.strftime(cfg["date_format"]) + "\n", style=pal["text"])
    body.append(now.strftime("Week %V · %Z"), style=pal["subtext"])
    if cfg["uptime"] and (up := uptime()):
        body.append(f"\n\nup {up}", style=pal["overlay"])
    return panel(ctx, body, f"[bold {pal['peach']}]{ctx['icons']['clock']} Clock")


def weather_card(ctx: dict) -> Panel:
    pal, icons, cfg = ctx["pal"], ctx["icons"], ctx["cfg"]
    wx, age = ctx["data"].get("weather", (None, None))
    if not wx:
        return panel(ctx, Text("weather unavailable", style=pal["overlay"]), f"[bold {pal['sky']}]Weather")
    kind, desc = WMO.get(wx["code"], ("cloud", "Unknown"))
    if not wx.get("is_day", 1) and kind in ("clear", "cloud"):
        kind = "night_" + kind
    unit, wind = ("°F", "mph") if cfg["units"] == "fahrenheit" else ("°C", "km/h")
    body = Text(justify="center")
    body.append(f"{icons[kind]}  {round(wx['temp'])}{unit}\n", style=f"bold {pal['yellow']}")
    body.append(f"{desc}\n", style=pal["text"])
    body.append(f"H {round(wx['hi'])}°  L {round(wx['lo'])}°  feels {round(wx['feels'])}°\n", style=pal["subtext"])
    body.append(f"{wx['humidity']}% humidity · {round(wx['wind'])} {wind}", style=pal["overlay"])
    return panel(ctx, body, f"[bold {pal['sky']}]{wx['place']}", age)


def fmt_price(p: float) -> str:
    return f"${p:,.0f}" if p >= 1000 else f"${p:,.2f}" if p >= 1 else f"${p:.4f}"


def markets_card(ctx: dict) -> Panel:
    pal, icons = ctx["pal"], ctx["icons"]
    stocks, s_age = ctx["data"].get("stocks", (None, None))
    crypto, c_age = ctx["data"].get("crypto", (None, None))
    rows = (stocks or []) + (crypto or [])
    title = f"[bold {pal['green']}]{icons['chart']} Markets"
    if not rows:
        return panel(ctx, Text("markets unavailable", style=pal["overlay"]), title)

    def table(chunk: list[dict]) -> Table:
        t = Table.grid(padding=(0, 2))
        t.add_column(style=f"bold {pal['text']}")
        t.add_column(justify="right", style=pal["text"])
        t.add_column(justify="right")
        for r in chunk:
            up = r["change"] >= 0
            t.add_row(r["sym"], fmt_price(r["price"]),
                      Text(f"{'▲' if up else '▼'} {abs(r['change']):.2f}%", style=pal["green"] if up else pal["red"]))
        return t

    if ctx["two_col"]:                      # long watchlist on a wide terminal → two columns
        half = math.ceil(len(rows) / 2)
        body = Table.grid(padding=(0, 3))
        body.add_column()
        body.add_column()
        body.add_row(table(rows[:half]), table(rows[half:]))
    else:
        body = table(rows)
    ages = [a for a in (s_age, c_age) if a is not None]
    return panel(ctx, body, title, max(ages) if ages else None)


CARDS = {"clock": clock_card, "weather": weather_card, "markets": markets_card}


# ── main ─────────────────────────────────────────────────────────────────────
def main() -> None:
    if ARGS & {"-h", "--help"}:
        print(__doc__.strip())
        return
    if INIT:
        init_config()
        return
    cfg = load_config()
    data = gather(cfg)
    if PREFETCH:
        return

    console = Console()
    pal = PALETTES.get(cfg["theme"]["flavor"], PALETTES["mocha"])
    icons = ICONS.get(cfg["theme"]["icons"], ICONS["emoji"])
    n_rows = sum(len(data[k][0] or []) for k in ("stocks", "crypto") if k in data)
    two_col = n_rows > 6 and console.width >= 120      # long watchlist gets a double-width card
    per_col = math.ceil(n_rows / 2) if two_col else n_rows
    style = dict(border_style=pal["surface"], box=BORDERS.get(cfg["theme"]["border"], box.ROUNDED),
                 padding=(1, 2), height=max(9, per_col + 4))    # all cards share one height
    ctx = {"cfg": cfg, "pal": pal, "icons": icons, "style": style, "data": data,
           "now": datetime.now().astimezone(), "width": console.width, "two_col": two_col}

    console.print()
    console.print(header(ctx))
    console.print()
    names = [c for c in cfg["cards"] if c in CARDS]
    cards = [CARDS[c](ctx) for c in names]
    if cards:                               # side by side when wide, stacked when narrow
        per_row = min(len(cards), 3) if console.width >= 96 else 1
        grid = Table.grid(expand=True, padding=(0, 1))
        for name in names[:per_row]:
            grid.add_column(ratio=2 if (name == "markets" and two_col and per_row > 1) else 1)
        for i in range(0, len(cards), per_row):
            grid.add_row(*cards[i:i + per_row])
        console.print(grid)
    console.print(Rule(style=pal["surface"]))
    console.print()


if __name__ == "__main__":
    main()
```

### What each part does

- **Flags & paths** — `--refresh` ignores freshness, `--prefetch` fills the
  cache and exits silently, `--demo` renders `DEMO_DATA`, `--debug` re-raises
  the real exception instead of falling back, `--init` writes `SAMPLE_CONFIG`.
- **Palettes / borders / defaults** — everything the config can change lives in
  one place. `load_config()` merges the TOML over `DEFAULTS` (tables are
  merged one level deep, so a partial `[theme]` works).
- **`cached(key, ttl, fetch, allow_fetch)`** returns `(data, age_seconds)`.
  It is the only place the cache is read or written; the fetch functions know
  nothing about it. The cache write sits in its own `try`, so a read-only cache
  directory costs a warning-free miss, not the freshly fetched data.
- **Data sources** — `geocode`, `fetch_weather`, `fetch_stocks`, `fetch_crypto`
  each return a small JSON-able value. Stocks and crypto raise when they get an
  empty answer (an error page or all-unknown symbols parses as zero rows), so a
  bad response never overwrites a good cache. Symbols are upper-cased and passed
  to CNBC as-is; a leading dot marks an index (`.SPX`) and is stripped for display.
- **`gather()`** — decides which sources the selected `cards` need, runs them in
  a thread pool, returns `{name: (data, age)}`.
- **Widgets** — `header()` plus one `*_card(ctx)` per card, registered in
  `CARDS`. `ctx` carries the config, palette, icons, shared panel style, the
  data, and `now`. `panel()` is the one helper that builds a `Panel` so every
  card gets the same border, padding, height and age subtitle.
- **`main()`** — computes one shared card height (so the row lines up), lays
  the cards out three-across on a wide terminal or stacked on a narrow one, and
  gives the Markets card a double-width column when the watchlist is longer than
  six rows and the terminal is at least 120 columns.

## 4. Make it runnable and test it

```sh
chmod +x ~/.local/bin/welcome
echo $PATH | tr ':' '\n' | grep -q "$HOME/.local/bin" || echo 'add ~/.local/bin to PATH'
welcome --init && $EDITOR ~/.config/welcome/config.toml
welcome
```

The first real run takes a second or two (geocode + weather + quotes); after
that it's instant. Run the acceptance checks from the Spec section; `--demo`
and the `https_proxy=http://127.0.0.1:9` trick let you test layout and offline
behaviour without waiting on or hitting any API.

## 5. Launch it when a terminal opens

Add to the **end** of `~/.zshrc`:

```zsh
# welcome dashboard — once per terminal; not in tmux panes, nvim, VS Code or over SSH
if [[ -z $WELCOME_SHOWN && -z $TMUX && -z $NVIM && -z $SSH_CONNECTION && $TERM_PROGRAM != vscode ]]; then
  export WELCOME_SHOWN=1
  welcome
fi
```

- `WELCOME_SHOWN` stops it re-running in nested shells (`zsh`, `su`, `nix-shell`, …).
- The other guards skip the places a dashboard is just noise or latency.
- If you already run `fastfetch` from `.zshrc`, replace that line with this
  block or keep both — `welcome` is about nine lines tall.
- Bash: same block in `~/.bashrc`. Fish: `if status is-interactive; and not set -q WELCOME_SHOWN; …`.
- If this lives in a git repo, `ln -s ~/code/welcome/welcome ~/.local/bin/welcome`
  and keep `config.toml` out of the repo (or commit a `config.example.toml`).

## 6. Background prefetch (recommended)

With this, the `welcome` that runs at launch only ever reads the cache — no
timeouts, no worst case, even when DNS is having a bad day.

`~/.config/systemd/user/welcome-prefetch.service`

```ini
[Unit]
Description=Refresh the welcome dashboard cache
After=network-online.target

[Service]
Type=oneshot
ExecStart=%h/.local/bin/welcome --prefetch
```

`~/.config/systemd/user/welcome-prefetch.timer`

```ini
[Unit]
Description=Refresh the welcome dashboard cache every 5 minutes

[Timer]
OnBootSec=20s
OnUnitActiveSec=5min
AccuracySec=30s

[Install]
WantedBy=timers.target
```

```sh
systemctl --user daemon-reload
systemctl --user enable --now welcome-prefetch.timer
systemctl --user list-timers welcome-prefetch.timer     # confirm it's scheduled
journalctl --user -u welcome-prefetch -n 5              # should be empty; errors land here
```

Then set `fetch_on_launch = false` in the config. `--prefetch` honours the
TTLs (markets every 5 min, weather every 15, geocode monthly), so the timer
can run often without hammering anything. `welcome --refresh` still forces a
fetch when you want one.

No systemd, or don't want a timer? Append `(welcome --prefetch &) >/dev/null 2>&1`
right after `welcome` in the shell hook — the terminal you just opened shows the
cache, and refreshes it for the next one.

On NixOS with Home Manager the same two units go in
`systemd.user.services.welcome-prefetch` / `systemd.user.timers.welcome-prefetch`.

## 7. Make it yours

Most things are config keys now, so start there:

- **Look** — `[theme]`: `flavor` picks any of the four Catppuccin palettes,
  `border` changes the box style, `gradient` is the list of palette names the
  greeting cycles through line by line (`["mauve", "blue"]` for a two-tone,
  `["text"]` for none), `icons = "emoji"` if you don't run a Nerd Font.
- **Greeting** — `greeting` is a template (`"Hey {name}"`, `"gm {name}"`,
  `"{name}@nixos"`) and `font` is any FIGlet font (`slant`, `small`, `big`,
  `doom`, `larry3d`, `ansi_shadow`; `pyfiglet -l` lists them, or `showfigfonts`).
  `taglines` is your own list; one is picked per launch.
- **Cards** — `cards` chooses which and in what order; leave out `"markets"` if
  you don't want quotes, and nothing for it is fetched.
- **Clock** — `time_format` / `date_format` are `strftime` strings; `uptime = false` hides the uptime line.
- **Weather** — `lat`/`lon` skip geocoding entirely (useful for "Home" vs a
  city Open-Meteo picks wrong). `units = "celsius"` switches wind to km/h too.
- **Tickers** — anything CNBC quotes: `AAPL`, `SPY`, `QQQ`; indices with a
  leading dot: `.SPX`, `.IXIC`, `.DJI`, `.VIX`. For CoinGecko use the id from the
  coin's URL (`coingecko.com/en/coins/solana` → `solana = "SOL"`).
- **Stock change** — day-over-day: last trade vs. CNBC's `previous_day_closing`.
  Quotes are real-time during market hours and hold the close otherwise.
- **Layout** — the numbers `96` (stack below this width) and `120` (double-width
  Markets card above this) in `main()`, and `padding=(1, 2)` in `style`.

### Adding a card

A card is a function that takes `ctx` and returns a `Panel`. Register it in
`CARDS`, add its name to `cards` in the config, done. A battery card:

```python
def battery_card(ctx: dict) -> Panel:
    pal = ctx["pal"]
    title = f"[bold {pal['teal']}]Battery"
    try:
        pct = int(Path("/sys/class/power_supply/BAT0/capacity").read_text())
    except (OSError, ValueError):
        return panel(ctx, Text("no battery", style=pal["overlay"]), title)
    bar = "█" * (pct // 10) + "░" * (10 - pct // 10)
    body = Text(justify="center")
    body.append(f"{pct}%\n", style=f"bold {pal['teal']}")
    body.append(bar, style=pal["teal"] if pct > 20 else pal["red"])
    return panel(ctx, body, title)

CARDS["battery"] = battery_card
```

If the card needs network data, add a `fetch_*` function and one
`pool.submit(cached, "key", ttl, fetch, allow)` line in `gather()`; read the
result in the card with `ctx["data"].get("key", (None, None))` and pass the age
to `panel()` so the corner shows it.

## 8. Troubleshooting

| Symptom | Fix |
|---|---|
| Boxes/`?` where icons should be | The terminal font isn't a Nerd Font — `icons = "emoji"`, or install one (`ttf-jetbrains-mono-nerd`) |
| "weather unavailable" | Check the city spelling, then `welcome --debug` for the real error; `lat`/`lon` bypasses geocoding |
| Wrong city picked | Be more specific: `city = "Springfield, Illinois"`, or set `lat`/`lon` |
| A stock is missing | CNBC doesn't know the symbol — check it on cnbc.com/quotes; indices need the leading dot (`.SPX`) |
| Everything says "unavailable" and you have a timer | The timer hasn't run yet or is failing: `journalctl --user -u welcome-prefetch` |
| Data looks old | Look at the age in the card corner; `welcome --refresh` forces a fetch |
| Times are off | `datetime.now().astimezone()` uses the system zone — `timedatectl` |
| Greeting is plain text | Neither `pyfiglet` nor `figlet` is installed, or the `font` name is unknown |
| Slow terminal startup | Something refetches every launch: is `~/.cache/welcome/` writable? Or switch to the section 6 timer |
| Traceback on launch | Python < 3.11 (no `tomllib`) — `python --version` |

## 9. Later — ideas backlog

Not built; listed so they can be picked off one at a time.

**Weather** — hourly temperature sparkline (`▁▂▃▅▇`) for the next 12 h,
sunrise/sunset, precipitation chance — all in the same Open-Meteo call
(`hourly=temperature_2m,precipitation_probability`, `daily=sunrise,sunset`).

**Markets** — a "US market closed · opens in 3h 12m" line computed locally from
NYSE hours; 7-day sparklines per ticker from a daily-history endpoint; a portfolio mode (holdings in the config → total value
and today's P/L).

**More cards** — system stats (load, RAM, disk, pending `checkupdates` count,
cached because it's slow); a todo card reading the first unchecked `- [ ]` lines
from a Markdown file or `task next`; a git card listing repos under `~/code`
with uncommitted or unpushed changes; `[countdowns]` in the config ("Graduation
in 240 days"); top-3 Hacker News titles (Firebase API, keyless); a quote or tip
of the day from a local file, seeded by the date so it stays put all day; an
ASCII-art/logo card next to the header (reuse a fastfetch logo file).

**Output modes** — `--json` so a Waybar custom module can reuse the same cache
instead of hitting the APIs again; `--card weather` to print a single card;
`--compact` one-liner you could allow inside tmux.

**Theming** — read colors from pywal/matugen (`~/.cache/wal/colors.json`) so it
re-themes with the wallpaper; a random accent color per day.

**Project shape** — turn it into a small repo (`pyproject.toml`, `welcome/`
package, `tests/` with mocked HTTP, `config.example.toml`, `install.sh`).
Or, once the design is settled, a compiled rewrite (Go + lipgloss, or Rust +
ratatui) brings the ~150 ms Python startup down to a few milliseconds; the
cache → cards → grid design ports directly.
