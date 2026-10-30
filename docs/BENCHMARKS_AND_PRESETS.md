# 📊 Benchmarks, Presets & Performance Tuning

Fine-tune your Lossless Scaling Frame Generation (`lsfg-vk` v2) configuration based on your GPU specifications, power envelope, and monitor refresh rate.

---

## 🎯 Recommended Playback Profiles

### 1. Ultra Cinema (24 FPS $\to$ 72 FPS / 120Hz–144Hz Displays)
*Recommended for 1080p / 4K movies and anime on dedicated GPUs (RTX 3060+, RX 6700XT+)*
```bash
lsfg -m 3 -f 1.0 mpv movie.mkv
```
- **Multiplier**: `3` ($24 \times 3 = 72$ FPS)
- **Flow Scale**: `1.0` (Full precision motion vectors)
- **Performance Mode**: `false`
- **Quality**: Flawless edge interpolation, cinematic cadence on 144Hz monitors ($72 \times 2 = 144$).

---

### 2. High-Refresh Motion (24 FPS $\to$ 96 FPS / 165Hz–240Hz Displays)
*Maximum smoothness for high-refresh gaming displays*
```bash
lsfg -m 4 -f 1.0 mpv anime.mkv
```
- **Multiplier**: `4` ($24 \times 4 = 96$ FPS)
- **Flow Scale**: `1.0`
- **Performance Mode**: `false`
- **Quality**: Ultra-dense synthetic frame insertion, eliminating 24 FPS judder completely.

---

### 3. Balanced / Streaming (60 FPS $\to$ 120 FPS / YouTube)
*Optimized for fast rendering and low latency streaming without thermal throttling*
```bash
lsfg -m 2 -f 0.75 mpv video.mp4
```
- **Multiplier**: `2` ($60 \times 2 = 120$ FPS)
- **Flow Scale**: `0.75`
- **Performance Mode**: `false`
- **Quality**: Ideal for live streams, gameplay recordings, and 60 FPS sports video.

---

### 4. Low-Power / Battery Saver (Handhelds & Laptops / Steam Deck)
*Optimized for Steam Deck, ROG Ally, and laptop integrated graphics (Radeon 680M/780M)*
```bash
lsfg -m 2 -f 0.5 -p mpv video.mkv
```
- **Multiplier**: `2`
- **Flow Scale**: `0.5`
- **Performance Mode**: `true`
- **Quality**: Slashes compute shader overhead by ~60% while maintaining smooth motion.

---

## ⚙️ Parameter Reference & Trade-offs

| Parameter | Configuration Key | Range / Options | Recommendation | Impact |
| :--- | :--- | :--- | :--- | :--- |
| **Multiplier** | `multiplier` | `2`, `3`, `4` | `3` (for 24fps) | Multiplies input frame presentation rate into the swapchain. |
| **Flow Scale** | `flow_scale` | `0.25` – `1.0` | `1.0` (dGPU) / `0.5` (iGPU) | Resolution of the optical flow motion grid. Higher values produce cleaner edges around complex movement. |
| **Performance Mode** | `performance_mode` | `true`, `false` | `false` | Enables reduced-instruction shader paths to conserve GPU power. |
| **FP16 Half-Precision** | `allow_fp16` | `true`, `false` | `true` | Executes compute passes in 16-bit floating point, reducing memory bandwidth usage. |
| **Pacing Mode** | `pacing_mode` | `vsync` | `vsync` | Synchronizes intermediate presentation with display vertical blank intervals. |
| **Present Override** | `override_present_mode` | `true`, `false` | `true` | Overrides swapchain present mode to FIFO to prevent screen tearing. |
