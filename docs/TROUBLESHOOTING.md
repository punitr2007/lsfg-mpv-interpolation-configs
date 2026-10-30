# 🛠️ Troubleshooting & Frequently Asked Questions

This guide addresses common issues encountered when setting up and running **Lossless Scaling Frame Generation (`lsfg-vk` v2)** with **mpv** on Linux.

---

### 1. `Unable to find base shader 'mipmaps' in DLL`

**Symptom**:
When launching a video with `lsfg`, the layer logs an error:
```
(lsfg-vk) [ERROR]: An error occured during initialization:
- Unable to find base shader 'mipmaps' in DLL
```

**Cause**:
`lsfg-vk` v2 requires native Vulkan SPIR-V compute shaders provided in **`lsfg-vk.dll`**. If your Steam installation of Lossless Scaling is on the default Windows branch, it only contains Direct3D bytecode in `Lossless.dll`.

**Solution**:
Switch your Steam installation to the official **`lsfg-vk`** beta branch:
1. Open the **Steam** desktop client.
2. Go to **Library** → Right-click **Lossless Scaling** → Select **Properties...**
3. Click on the **Betas** (or *Game Versions & Betas*) tab.
4. In the **Beta Participation** dropdown, select **`lsfg-vk`**.
5. Steam will automatically download the branch update, providing `lsfg-vk.dll`.
6. Verify the file exists:
   ```bash
   ls -l ~/.local/share/Steam/steamapps/common/Lossless\ Scaling/lsfg-vk.dll
   ```

---

### 2. `Unsupported configuration version (must be 2)` or `Unknown key in configuration: game`

**Symptom**:
The Vulkan loader fails or `lsfg-vk-cli` reports:
```
(lsfg-vk) [ERROR]: Failed to initialize global info:
- Unsupported configuration version (must be 2).
```
or:
```
(lsfg-vk) [ERROR]: Unknown key in configuration: game
```

**Cause**:
Your `~/.config/lsfg-vk/conf.toml` is written in the deprecated v1 format (using `version = 1` and `[[game]]`). The modern `lsfg-vk` v2 layer strictly validates syntax and rejects unknown keys.

**Solution**:
Re-run `./install.sh` or update your `~/.config/lsfg-vk/conf.toml` to the v2 schema:
```toml
version = 2

[global]
dll = "/home/your_username/.local/share/Steam/steamapps/common/Lossless Scaling/lsfg-vk.dll"
allow_fp16 = true
log_level = "info"

[[profile]]
name = "mpv"
active_in = ["mpv"]
multiplier = 3
flow_scale = 1.0
performance_mode = false
pacing_mode = "vsync"
override_present_mode = true
```

Validate your file using `lsfg-vk-cli`:
```bash
lsfg-vk-cli validate -c ~/.config/lsfg-vk/conf.toml -p
```

---

### 3. Dual-Layer Collision / Old v1 Files

**Symptom**:
`lsfg-vk-cli healthcheck` reports:
```
Healthcheck was able to find files from old lsfg-vk installations:
- /home/user/.local/lib/liblsfg-vk.so
- /home/user/.local/share/vulkan/implicit_layer.d/VkLayer_LS_frame_generation.json
```
and `vulkaninfo` shows two conflicting Lossless Scaling layers:
`VK_LAYER_LS_frame_generation` and `VK_LAYER_LSFGVK_frame_generation`.

**Cause**:
Prior manual installations placed an implicit layer manifest in `~/.local/share/vulkan/implicit_layer.d/`. When Vulkan initializes, the loader attempts to load both the old v1 translation layer and the modern v2 layer simultaneously.

**Solution**:
1. Deactivate the obsolete local v1 manifest:
   ```bash
   mv ~/.local/share/vulkan/implicit_layer.d/VkLayer_LS_frame_generation.json \
      ~/.local/share/vulkan/implicit_layer.d/VkLayer_LS_frame_generation.json.bak
   ```
2. The `lsfg` launcher automatically sets `export DISABLE_LSFG=1` to guarantee the legacy v1 layer stays dormant.

---

### 4. mpv OSD or MangoHud Still Shows 24 FPS

**Symptom**:
Pressing `Shift+I` in mpv shows:
`FPS: 24.000 (specified) / 24.000 (display)`
and MangoHud displays `24 FPS`.

**Explanation**:
- **Decoder Rate vs Presentation Rate**:
  mpv's internal video clock, OSD, and demuxer report the rate at which source frames are decoded from the video file (e.g., 23.976 or 24.000 FPS).
- The `lsfg-vk` Vulkan layer hooks **`vkQueuePresentKHR`** — *after* mpv finishes rendering each frame. It synthesizes intermediate frames and presents them directly to the display compositor at $24 \times 3 = 72$ FPS.
- If MangoHud is placed before `lsfg-vk` in the Vulkan layer stack, it measures mpv's queue submissions (24 FPS).
- You can observe the interpolation directly in pans, motion smoothness, or by checking debug logs:
  ```bash
  lsfg -d mpv video.mkv
  ```

---

### 5. Hardware Decoding Crash / Black Screen on NVIDIA

**Symptom**:
mpv crashes on startup or produces a frozen black screen with NVIDIA proprietary drivers.

**Cause**:
Using direct CUDA/NVDEC surfaces without memory copy (`hwdec=nvdec`) creates resource sharing deadlocks between the CUDA context and the Vulkan swapchain presentation pipeline.

**Solution**:
Always use copy-back decoding in your `mpv.conf`:
```ini
hwdec=nvdec-copy
hwdec-codecs=all
```
For AMD and Intel GPUs, use:
```ini
hwdec=vaapi-copy
hwdec-codecs=all
```

---

### 6. Video Tearing or Microstutter on High-Refresh Displays

**Symptom**:
Video plays smoothly but exhibits intermittent horizontal tearing or micro-stutters on 120Hz/144Hz displays under Wayland or X11.

**Solution**:
1. Ensure your profile enables VSync presentation override in `conf.toml`:
   ```toml
   pacing_mode = "vsync"
   override_present_mode = true
   ```
2. Verify that mpv has internal software interpolation disabled:
   ```ini
   interpolation=no
   video-sync=audio
   ```
   Allowing mpv to perform `display-resample` simultaneously with `lsfg-vk` creates severe frame pacing cadence conflicts.
