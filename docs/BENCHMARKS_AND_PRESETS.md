# 📊 Benchmarks, Presets & Performance Tuning

Optimize your playback experience depending on your GPU specifications, display refresh rate, and power target.

---

## Recommended Profiles

### 1. Ultra Cinema (24 FPS $\to$ 72 FPS / 120Hz-144Hz Displays)
*Best for anime, movies, YouTube 24/30fps videos on modern dedicated GPUs (RTX 3060+, RX 6700XT+)*
```bash
lsfg -m 3 -f 1.0 mpv video.mkv
```
- **Multiplier**: `3`
- **Flow Scale**: `1.0`
- **Performance Mode**: `false`

### 2. High Refresh Smooth (24 FPS $\to$ 96 FPS / 165Hz-240Hz Displays)
*Extreme smoothness for high-refresh-rate displays*
```bash
lsfg -m 4 -f 1.0 mpv video.mkv
```
- **Multiplier**: `4`
- **Flow Scale**: `1.0`

### 3. Balanced / Streaming (4K 60 FPS $\to$ 120 FPS / YouTube)
*Optimized for fast rendering and low latency streaming without thermal throttle*
```bash
lsfg -m 2 -f 0.5 -p mpv video.mkv
```
- **Multiplier**: `2`
- **Flow Scale**: `0.5`
- **Performance Mode**: `true`

---

## Parameter Reference Table

| Flag | Parameter | Values | Description |
| :--- | :--- | :--- | :--- |
| `-m, --multiplier` | `multiplier` | `2`, `3`, `4` | Target frame interpolation factor |
| `-f, --flow-scale` | `flow_scale` | `0.5` to `1.0` | Optical flow vector resolution (lower = faster, higher = sharper edges) |
| `-p, --performance` | `performance_mode` | `true`, `false` | Enables lightweight compute shaders for low power |
| `-h, --hdr` | `hdr_mode` | `true`, `false` | Enables 10-bit wide-gamut HDR color preservation |
