#!/usr/bin/env bash
# ==============================================================================
# lsfg-mpv-interpolation-configs — Installer & Setup Script (lsfg-vk v2)
# ==============================================================================

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BOLD}${BLUE}==============================================================================${NC}"
echo -e "${BOLD}${BLUE}   Lossless Scaling Frame Generation (lsfg-vk v2) Setup for mpv on Linux      ${NC}"
echo -e "${BOLD}${BLUE}==============================================================================${NC}\n"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_BIN="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.config/lsfg-vk"
MPV_CONFIG_DIR="${HOME}/.config/mpv"
MPV_PROFILES_DIR="${MPV_CONFIG_DIR}/profiles"
VULKAN_LOCAL_LAYER_DIR="${HOME}/.local/share/vulkan/implicit_layer.d"

mkdir -p "${INSTALL_BIN}" "${CONFIG_DIR}" "${MPV_CONFIG_DIR}" "${MPV_PROFILES_DIR}"

# ── 1. Check System Packages & Vulkan Layer ───────────────────────────────────
echo -e "${BLUE}[1/6] Checking system packages and Vulkan layer...${NC}"

# Check for mpv
if command -v mpv >/dev/null 2>&1; then
    MPV_VER=$(mpv --version | head -n1)
    echo -e "  ${GREEN}✓ Found mpv:${NC} ${MPV_VER}"
else
    echo -e "  ${YELLOW}! mpv is not installed.${NC} Install via: sudo pacman -S mpv"
fi

# Check for lsfg-vk layer package
HAS_LSFGVK_LAYER=0
if [[ -f "/usr/lib/liblsfg-vk-layer.so" || -f "/usr/share/vulkan/implicit_layer.d/VkLayer_LSFGVK_frame_generation.json" ]]; then
    HAS_LSFGVK_LAYER=1
    echo -e "  ${GREEN}✓ Found system lsfg-vk v2 Vulkan Layer in /usr/lib/${NC}"
elif command -v lsfg-vk-cli >/dev/null 2>&1; then
    HAS_LSFGVK_LAYER=1
    echo -e "  ${GREEN}✓ Found lsfg-vk-cli on system.${NC}"
else
    echo -e "  ${YELLOW}! lsfg-vk v2 package not found in system libraries.${NC}"
    echo -e "    On Arch Linux / CachyOS, install it via AUR:"
    echo -e "      ${BOLD}yay -S lsfg-vk-git${NC}   (or paru -S lsfg-vk-git)"
fi

# ── 2. Locate lsfg-vk.dll / Lossless.dll from Steam ────────────────────────────
echo -e "\n${BLUE}[2/6] Detecting Lossless Scaling DLL from Steam...${NC}"

STEAM_DLL_PATHS=(
    # Preferred v2 native shader DLL (Steam Beta branch 'lsfg-vk')
    "${HOME}/.local/share/Steam/steamapps/common/Lossless Scaling/lsfg-vk.dll"
    "${HOME}/.steam/steam/steamapps/common/Lossless Scaling/lsfg-vk.dll"
    "${HOME}/.steam/root/steamapps/common/Lossless Scaling/lsfg-vk.dll"
    "${HOME}/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/Lossless Scaling/lsfg-vk.dll"
    "/mnt/storage/SteamLibrary/steamapps/common/Lossless Scaling/lsfg-vk.dll"
    "${HOME}/Local_Codebase/Projects/Lossless Scaling/lsfg-vk.dll"

    # Fallback to standard Lossless.dll
    "${HOME}/.local/share/Steam/steamapps/common/Lossless Scaling/Lossless.dll"
    "${HOME}/.steam/steam/steamapps/common/Lossless Scaling/Lossless.dll"
    "${HOME}/.steam/root/steamapps/common/Lossless Scaling/Lossless.dll"
    "${HOME}/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/Lossless Scaling/Lossless.dll"
    "/mnt/storage/SteamLibrary/steamapps/common/Lossless Scaling/Lossless.dll"
    "${HOME}/Local_Codebase/Projects/Lossless Scaling/Lossless.dll"
)

FOUND_DLL=""
for dll in "${STEAM_DLL_PATHS[@]}"; do
    if [[ -f "$dll" ]]; then
        FOUND_DLL="$dll"
        break
    fi
done

if [[ -n "$FOUND_DLL" ]]; then
    if [[ "$(basename "$FOUND_DLL")" == "lsfg-vk.dll" ]]; then
        echo -e "  ${GREEN}✓ Found native v2 shader library:${NC} ${FOUND_DLL}"
    else
        echo -e "  ${GREEN}✓ Found Lossless.dll at:${NC} ${FOUND_DLL}"
        echo -e "    ${YELLOW}Tip: For native v2 Vulkan shaders, switch Lossless Scaling to the 'lsfg-vk' Beta branch in Steam:${NC}"
        echo -e "         Steam Library -> Right Click 'Lossless Scaling' -> Properties -> Betas -> select 'lsfg-vk'"
    fi
else
    echo -e "  ${YELLOW}! Could not auto-detect lsfg-vk.dll or Lossless.dll in standard Steam library paths.${NC}"
    echo -e "    You can specify it manually in ~/.config/lsfg-vk/conf.toml or with --dll."
    FOUND_DLL="${HOME}/.local/share/Steam/steamapps/common/Lossless Scaling/lsfg-vk.dll"
fi

# ── 3. Resolve Stale / Conflicting Legacy v1 Layers ───────────────────────────
echo -e "\n${BLUE}[3/6] Checking for conflicting legacy Vulkan layers...${NC}"

V1_MANIFEST="${VULKAN_LOCAL_LAYER_DIR}/VkLayer_LS_frame_generation.json"
if [[ -f "${V1_MANIFEST}" ]]; then
    echo -e "  ${YELLOW}! Found obsolete v1 layer manifest:${NC} ${V1_MANIFEST}"
    echo -e "    Backing up to ${V1_MANIFEST}.bak to prevent loader conflict with v2..."
    mv -f "${V1_MANIFEST}" "${V1_MANIFEST}.bak" 2>/dev/null || true
    echo -e "  ${GREEN}✓ Legacy v1 manifest deactivated.${NC}"
else
    echo -e "  ${GREEN}✓ No conflicting legacy v1 layer manifests found.${NC}"
fi

# ── 4. Setup ~/.config/lsfg-vk/conf.toml (v2 Schema) ──────────────────────────
echo -e "\n${BLUE}[4/6] Configuring lsfg-vk (~/.config/lsfg-vk/conf.toml)...${NC}"
CONFIG_FILE="${CONFIG_DIR}/conf.toml"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    cat > "${CONFIG_FILE}" << EOF
# ==============================================================================
# lsfg-vk Configuration (v2 Schema)
# Location: ~/.config/lsfg-vk/conf.toml
# Documentation: https://lsfg-vk.dev
# ==============================================================================

version = 2

[global]
dll = "${FOUND_DLL}"
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
EOF
    echo -e "  ${GREEN}✓ Created v2 configuration:${NC} ${CONFIG_FILE}"
elif grep -q "^version = 1" "${CONFIG_FILE}" 2>/dev/null; then
    echo -e "  ${YELLOW}! Found older version 1 configuration. Backing up and upgrading to version 2...${NC}"
    cp -f "${CONFIG_FILE}" "${CONFIG_FILE}.v1.bak"
    cat > "${CONFIG_FILE}" << EOF
# ==============================================================================
# lsfg-vk Configuration (v2 Schema)
# Location: ~/.config/lsfg-vk/conf.toml
# Documentation: https://lsfg-vk.dev
# ==============================================================================

version = 2

[global]
dll = "${FOUND_DLL}"
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
EOF
    echo -e "  ${GREEN}✓ Upgraded to version 2 schema (backup saved to conf.toml.v1.bak).${NC}"
else
    echo -e "  ${GREEN}✓ Existing v2 conf.toml preserved.${NC}"
fi

# Validate if lsfg-vk-cli is present
if command -v lsfg-vk-cli >/dev/null 2>&1; then
    echo -e "  Running configuration validation..."
    lsfg-vk-cli validate -c "${CONFIG_FILE}" >/dev/null 2>&1 && echo -e "  ${GREEN}✓ Configuration is valid.${NC}" || true
fi

# ── 5. Install 'lsfg' Launcher Binary ──────────────────────────────────────────
echo -e "\n${BLUE}[5/6] Installing 'lsfg' launcher script to ~/.local/bin/...${NC}"
cp -f "${SCRIPT_DIR}/bin/lsfg" "${INSTALL_BIN}/lsfg"
chmod +x "${INSTALL_BIN}/lsfg"
echo -e "  ${GREEN}✓ Installed to:${NC} ${INSTALL_BIN}/lsfg"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo -e "\n  ${YELLOW}Notice:${NC} Ensure ${BOLD}~/.local/bin${NC} is in your PATH. Add this to ~/.bashrc or ~/.zshrc:"
    echo -e "    export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# ── 6. Configure mpv ──────────────────────────────────────────────────────────
echo -e "\n${BLUE}[6/6] Setting up mpv configuration and [lsfg] profile...${NC}"

# Copy modular profile snippet
cp -f "${SCRIPT_DIR}/config/mpv/profiles/lsfg.conf" "${MPV_PROFILES_DIR}/lsfg.conf"
echo -e "  ${GREEN}✓ Copied profile snippet:${NC} ${MPV_PROFILES_DIR}/lsfg.conf"

MPV_CONF="${MPV_CONFIG_DIR}/mpv.conf"
if [[ -f "${MPV_CONF}" ]]; then
    if ! grep -q "\[lsfg\]" "${MPV_CONF}"; then
        echo -e "  Appending [lsfg] profile to ${MPV_CONF}..."
        cat >> "${MPV_CONF}" << 'EOF'

# ===== Profile: lsfg-vk (Lossless Scaling Frame Generation v2) =====
[lsfg]
vo=gpu-next
gpu-api=vulkan
hwdec=nvdec-copy
hwdec-codecs=all
interpolation=no
video-sync=audio
EOF
        echo -e "  ${GREEN}✓ Added [lsfg] profile to mpv.conf${NC}"
    else
        echo -e "  ${GREEN}✓ mpv.conf already contains [lsfg] profile.${NC}"
    fi
else
    cp -f "${SCRIPT_DIR}/config/mpv/mpv.conf" "${MPV_CONF}"
    echo -e "  ${GREEN}✓ Created ${MPV_CONF}${NC}"
fi

# ── Finished ──────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}${GREEN}✨ Setup completed successfully! ✨${NC}\n"
echo -e "Ready to launch:"
echo -e "  ${BOLD}lsfg mpv /path/to/movie.mkv${NC}             # 24 FPS -> 72 FPS (3x multiplier)"
echo -e "  ${BOLD}lsfg -m 4 -f 1.0 mpv anime.mkv${NC}          # 24 FPS -> 96 FPS (4x multiplier)"
echo -e "  ${BOLD}lsfg yt \"https://youtu.be/...\"${NC}          # YouTube streaming with caching\n"
