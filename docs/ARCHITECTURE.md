# 🏗️ Architecture & How It Works

This document explains the technical architecture behind **Lossless Scaling Frame Generation on Linux (`lsfg-vk`)** when used with **mpv** and Vulkan.

---

## 1. Overview Diagram

```
+-------------------------------------------------------------+
|                        mpv Media Player                     |
|                                                             |
|  [ Video Stream (24 FPS) ]                                  |
|               ↓                                             |
|  [ Hardware Decoder (nvdec-copy / vaapi-copy) ]             |
|               ↓                                             |
|  [ Video Output: vo=gpu-next, gpu-api=vulkan ]              |
+-------------------------------------------------------------+
                              ↓ (vkQueuePresentKHR)
+-------------------------------------------------------------+
|           Vulkan Implicit Layer (VK_LAYER_LS_frame_generation) |
|                                                             |
|  [ DXBC Translator (Converts Lossless.dll DXBC -> SPIR-V) ] |
|  [ Optical Flow Engine (Motion Vector Analysis) ]           |
|  [ Frame Interpolator (Generates 2 intermediate frames) ]   |
+-------------------------------------------------------------+
                              ↓ (72 FPS Presentation)
+-------------------------------------------------------------+
|               Vulkan Swapchain / Display Server             |
|                  (Wayland / X11 Compositor)                 |
|                                                             |
|              [ High Refresh Rate Display (120Hz+) ]          |
+-------------------------------------------------------------+
```

---

## 2. Vulkan Implicit Layer Interception

`lsfg-vk` is implemented as an **implicit Vulkan layer** (`VK_LAYER_LS_frame_generation`). 

When any Vulkan application (like `mpv --gpu-api=vulkan`) initializes its Vulkan instance and swapchain:
1. The Vulkan loader (`libvulkan.so`) reads manifests located in `~/.local/share/vulkan/implicit_layer.d/` or `/usr/share/vulkan/implicit_layer.d/`.
2. The layer intercepts `vkCreateInstance`, `vkCreateDevice`, and crucially **`vkQueuePresentKHR`**.
3. For every frame that `mpv` presents to the swapchain:
   - The layer captures the current frame and previous frame textures.
   - It executes the optical flow and interpolation compute shaders extracted from `Lossless.dll`.
   - It submits $N-1$ synthetic intermediate frames directly into the Vulkan swapchain before presenting the real next frame.

---

## 3. Why Decoding FPS Displays 24 FPS while Display Renders at 72 FPS

A common source of confusion is checking tools like **MangoHud** or mpv's internal stats (`Shift+I`):
- **Decoder / Player Level**: mpv is only decoding 24 frames every second from the source container. mpv's internal clock and OSD accurately report `24 fps`.
- **MangoHud Level**: When placed before `lsfg-vk` in the Vulkan layer chain, MangoHud measures the rate at which mpv calls presentation before generation, displaying 24 fps.
- **Display / Swapchain Level**: The monitor compositor receives $24 \times 3 = 72$ frames per second (or $24 \times 2 = 48$ / $24 \times 4 = 96$).

You can visually confirm the interpolation by pausing on rapid motion or observing the ultra-smooth camera pans on high-refresh-rate displays.

---

## 4. The v1 vs v2 Layer Engine Nuance

| Version | Engine Mechanism | DLL Requirement | Compatibility Status |
| :--- | :--- | :--- | :--- |
| **v1 (Active)** | Direct DXBC → SPIR-V Translation | `Lossless.dll` (Steam standard) | ✅ **100% Working** |
| **v2 (Experimental)** | Native Vulkan Bytecode | `lsfg-vk.dll` (Unreleased format) | ❌ Incompatible with current Steam builds |

The wrapper script `lsfg` automatically sets `DISABLE_LSFGVK=1` to prevent broken v2 system layers from interfering with the functional v1 DXBC pipeline.
