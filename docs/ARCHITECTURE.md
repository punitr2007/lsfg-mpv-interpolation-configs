# 🏗️ Architecture & Technical Deep Dive

This document details the architecture and operational mechanics of **Lossless Scaling Frame Generation on Linux (`lsfg-vk` v2)** integrated with **mpv** and the Vulkan graphics ecosystem.

---

## 1. High-Level Pipeline Architecture

```
+-------------------------------------------------------------------------+
|                        mpv Media Player (User Space)                    |
|                                                                         |
|  [ Video Demuxer ] -> [ Stream: 24.000 FPS ]                            |
|         ↓                                                               |
|  [ Hardware Video Decoder (nvdec-copy / vaapi-copy) ]                   |
|         ↓ (Decoded System Frames)                                       |
|  [ Video Output Engine (vo=gpu-next, gpu-api=vulkan) ]                   |
|         ↓ (Rendered Frame Textures)                                     |
+-------------------------------------------------------------------------+
                                  ↓ vkQueuePresentKHR
+-------------------------------------------------------------------------+
|        Vulkan Layer: VK_LAYER_LSFGVK_frame_generation (v2 Native)        |
|                                                                         |
|  [ Process Identifier & Profile Engine ] (Matches active_in = ["mpv"])  |
|  [ Native Vulkan Compute Shaders ] (Extracted from lsfg-vk.dll)         |
|         ├── Timeline Semaphore Synchronization                          |
|         ├── Optical Flow Motion Estimation Pass (flow_scale: 1.0)       |
|         ├── Bidirectional Motion Vector Smoothing                       |
|         └── Synthetic Intermediate Frame Synthesis (2x / 3x / 4x)       |
+-------------------------------------------------------------------------+
                                  ↓ Multiplied Presentation (72 / 96 FPS)
+-------------------------------------------------------------------------+
|            Vulkan Swapchain / Display Server (Wayland / X11)            |
|                                                                         |
|  [ Wayland Compositor (KWin / Mutter / Hyprland) or X11 Server ]        |
|         ↓                                                               |
|  [ Monitor Display Engine (120Hz / 144Hz / 240Hz) ]                     |
+-------------------------------------------------------------------------+
```

---

## 2. Vulkan Implicit Layer Interception

Unlike standalone post-processing injectors or screen-capture tools (e.g. OBS or MediaProjection), `lsfg-vk` operates as an **implicit Vulkan layer**:

1. **Manifest Registration**:
   The layer manifest `/usr/share/vulkan/implicit_layer.d/VkLayer_LSFGVK_frame_generation.json` declares the layer to the Vulkan loader (`libvulkan.so.1`):
   ```json
   {
     "file_format_version": "1.1.0",
     "layer": {
       "name": "VK_LAYER_LSFGVK_frame_generation",
       "implementation_version": "2",
       "library_path": "liblsfg-vk-layer.so"
     }
   }
   ```
2. **Interface Negotiation**:
   The layer exports `vkNegotiateLoaderLayerInterfaceVersion`. When mpv initializes Vulkan, the loader links `liblsfg-vk-layer.so` directly into the dispatch call chain.
3. **Queue Presentation Hook**:
   The layer intercepts `vkQueuePresentKHR`. When mpv submits a rendered video frame:
   - The layer captures the current frame texture alongside the prior frame texture.
   - It runs GPU compute shaders to calculate optical flow motion vectors.
   - For a **3x multiplier**, it dispatches two intermediate synthetic frame renders before the true subsequent frame.
   - All frames are submitted sequentially to the Vulkan swapchain using hardware timeline semaphores.

---

## 3. The v1 vs v2 Architecture Evolution

| Architectural Metric | Legacy v1 Engine (`liblsfg-vk.so`) | Modern v2 Engine (`liblsfg-vk-layer.so`) |
| :--- | :--- | :--- |
| **Shader Source** | Windows DXBC translated at runtime | Native SPIR-V compute bytecode (`lsfg-vk.dll`) |
| **Synchronization** | CPU polling / basic fences | Vulkan timeline semaphores |
| **Memory Footprint** | ~600MB–1.2GB VRAM overhead | ~80MB–150MB VRAM overhead |
| **FP16 Acceleration** | Partial / Experimental | Native half-precision FP16 pipeline |
| **Configuration** | Legacy `conf.toml` (version 1) | Structured profiles `conf.toml` (version 2) |
| **Presentation Pacing** | Ungated presentation | VSync FIFO override & pacing engine |

The modern v2 engine eliminates runtime DXBC translation, slashing input latency, frame drop risk, and GPU memory consumption.

---

## 4. Decoder Clock vs Presentation Clock

A frequent question is why mpv's internal diagnostics (`Shift+I`) or FPS counters display the source video frame rate:

- **Player & Demuxer Clock**:
  mpv's playback thread is responsible for decoding and scheduling frames from the source container. A 24 FPS video file contains exactly 24 frames for every second of audio. mpv correctly schedules presentation at 24 FPS.
- **Swapchain Clock**:
  The interpolation happens **inside the Vulkan swapchain presentation call**. When mpv calls `vkQueuePresentKHR` once, `lsfg-vk` presents 3 frames to the display compositor.
- Thus, the monitor receives and renders 72 individual frames per second, while mpv's decoder remains completely decoupled and lightweight.

---

## 5. Hardware Decoding Integration (`nvdec-copy` / `vaapi-copy`)

In `mpv.conf`, the `[lsfg]` profile specifies copy-back decoding:
```ini
hwdec=nvdec-copy
hwdec-codecs=all
```

**Why Copy-Back?**
Standard zero-copy hardware decoding creates a direct hardware surface handle owned by the video decoder engine (e.g. CUDA on NVIDIA or VA-API on AMD). When a Vulkan layer attempts to read, bind, and compute across these surfaces within `vkQueuePresentKHR`, driver race conditions or deadlocks frequently occur. Using copy-back ensures decoded frames are cleanly copied into system Vulkan images, ensuring 100% stability.
