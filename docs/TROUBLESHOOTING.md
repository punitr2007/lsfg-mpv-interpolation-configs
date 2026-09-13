# 🛠️ Troubleshooting & Frequently Asked Questions

---

### 1. `(lsfg-vk) [ERROR]: - Unsupported configuration version (must be 2)`

**Cause**: You have an incompatible v2 layer binary trying to parse a v1 configuration or vice versa.
**Solution**:
1. Suppress the v2 layer:
   ```bash
   export DISABLE_LSFGVK=1
   ```
2. Ensure your `~/.config/lsfg-vk/conf.toml` begins with `version = 1`.

---

### 2. The video is still playing at 24 FPS with no smoothness

**Checklist**:
1. **Config section missing**: In v1 `conf.toml`, settings MUST be enclosed within a `[[game]]` block for `mpv`:
   ```toml
   version = 1

   [global]
   dll = "/path/to/Lossless.dll"

   [[game]]
   exe = "mpv"
   multiplier = 3
   flow_scale = 1.0
   ```
2. **Missing `gpu-api=vulkan`**: mpv must render via Vulkan. Add `--gpu-api=vulkan --vo=gpu-next` to your command or use the `lsfg` launcher.
3. **Double interpolation collision**: Ensure `interpolation=no` in mpv so mpv's internal `tscale` doesn't conflict with Vulkan swapchain injection.

---

### 3. Missing `liblsfg-vk.so` or Layer not loading

Check if the Vulkan loader can detect the implicit layer:
```bash
VK_LOADER_DEBUG=all mpv --vo=gpu-next --gpu-api=vulkan /path/to/video.mkv 2>&1 | grep -i "LS_frame_generation"
```
Ensure `~/.local/share/vulkan/implicit_layer.d/VkLayer_LS_frame_generation.json` has an absolute path in `"library_path"`, e.g. `"/home/user/.local/lib/liblsfg-vk.so"`.

---

### 4. Hardware Decoding Crashing or Black Screen on NVIDIA

On NVIDIA systems, using CUDA headless decoders directly with Vulkan renderers can cause device context crashes. Always use copy-back decoding:
```ini
hwdec=nvdec-copy
hwdec-codecs=all
```
For AMD / Intel GPUs:
```ini
hwdec=vaapi-copy
hwdec-codecs=all
```
