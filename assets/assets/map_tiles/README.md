# Local Map Tiles

This directory is for offline map tiles. The app will use these tiles when available, and fall back to online tiles when not found.

## How to add tiles

1. Download map tiles for your region (zoom levels 0-18 recommended)
2. Organize them in the standard OSM tile structure: `{z}/{x}/{y}.png`
3. Place them in this directory

Example structure:
```
assets/map_tiles/
├── 0/
│   └── 0/
│       └── 0.png
├── 1/
│   ├── 0/
│   │   ├── 0.png
│   │   └── 1.png
│   └── 1/
│       ├── 0.png
│       └── 1.png
...
```

## Tile Sources

- OpenStreetMap tile servers (check usage terms)
- MapTiler (free tier available)
- Other OSM-compatible tile providers

## Note

If no local tiles are found, the app will automatically use online tiles as a fallback.
