#!/usr/bin/env bash
# ==============================================================================
# lsfg-mpv-interpolation-configs — Installer Script
# ==============================================================================

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BOLD}${BLUE}=== Lossless Scaling (lsfg-vk) mpv Setup for Linux ===${NC}\n"

# 1. Directory creation
INSTALL_BIN="${HOME}/.local/bin"
INSTALL_LIB="${HOME}/.local/lib"
INSTALL_LAYER_DIR="${HOME}/.local/share/vulkan/implicit_layer.d"
CONFIG_DIR="${HOME}/.config/lsfg-vk"
MPV_CONFIG_DIR="${HOME}/.config/mpv"

mkdir -p "${INSTALL_BIN}" "${INSTALL_LIB}" "${INSTALL_LAYER_DIR}" "${CONFIG_DIR}" "${MPV_CONFIG_DIR}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 2. Locate Lossless.dll
echo -e "${BLUE}[1/5] Checking for Lossless Scaling (Lossless.dll)...${NC}"
CANDIDATE_DLLS=(
    "${HOME}/.local/share/Steam/steamapps/common/Lossless Scaling/Lossless.dll"
    "${HOME}/.steam/steam/steamapps/common/Lossless Scaling/Lossless.dll"
    "${HOME}/.steam/root/steamapps/common/Lossless Scaling/Lossless.dll"
    "/mnt/storage/SteamLibrary/steamapps/common/Lossless Scaling/Lossless.dll"
    "${HOME}/Local_Codebase/Projects/Lossless Scaling/Lossless.dll"
)

FOUND_DLL=""
for dll in "${CANDIDATE_DLLS[@]}"; do
    if [[ -f "$dll" ]]; then
        FOUND_DLL="$dll"
        break
    fi
done

if [[ -n "$FOUND_DLL" ]]; then
    echo -e "  ${GREEN}✓ Found Lossless.dll at:${NC} ${FOUND_DLL}"
else
    echo -e "  ${YELLOW}! Could not auto-detect Lossless.dll in standard Steam library paths.${NC}"
    echo -e "  You can specify it manually in ~/.config/lsfg-vk/conf.toml later."
    FOUND_DLL="${HOME}/.local/share/Steam/steamapps/common/Lossless Scaling/Lossless.dll"
fi

# 3. Locate & install liblsfg-vk.so (v1)
echo -e "\n${BLUE}[2/5] Setting up lsfg-vk v1 Vulkan Layer library...${NC}"
TARGET_LIB="${INSTALL_LIB}/liblsfg-vk.so"

if [[ -f "${TARGET_LIB}" ]]; then
    echo -e "  ${GREEN}✓ liblsfg-vk.so is already in ~/.local/lib/${NC}"
elif [[ -f "${SCRIPT_DIR}/bin/liblsfg-vk.so" ]]; then
    cp -f "${SCRIPT_DIR}/bin/liblsfg-vk.so" "${TARGET_LIB}"
    echo -e "  ${GREEN}✓ Copied liblsfg-vk.so to ~/.local/lib/${NC}"
elif [[ -f "${HOME}/Downloads/Lossless Scaling/bin/lsfg-vk_noui.zip" ]]; then
    echo -e "  Extracting from ~/Downloads/Lossless Scaling/bin/lsfg-vk_noui.zip..."
    unzip -qo "${HOME}/Downloads/Lossless Scaling/bin/lsfg-vk_noui.zip" -d /tmp/lsfg_extracted
    cp -f /tmp/lsfg_extracted/lib/liblsfg-vk.so "${TARGET_LIB}"
    rm -rf /tmp/lsfg_extracted
    echo -e "  ${GREEN}✓ Installed liblsfg-vk.so into ~/.local/lib/${NC}"
else
    echo -e "  ${YELLOW}! liblsfg-vk.so not found.${NC}"
    echo -e "  Please ensure liblsfg-vk.so is placed in ${INSTALL_LIB}/"
fi

# 4. Generate layer manifest
echo -e "\n${BLUE}[3/5] Registering Vulkan Implicit Layer manifest...${NC}"
MANIFEST_FILE="${INSTALL_LAYER_DIR}/VkLayer_LS_frame_generation.json"
cat > "${MANIFEST_FILE}" << EOF
{
  "file_format_version": "1.0.0",
  "layer": {
    "name": "VK_LAYER_LS_frame_generation",
    "type": "GLOBAL",
    "api_version": "1.4.313",
    "library_path": "${TARGET_LIB}",
    "implementation_version": "1",
    "description": "Lossless Scaling frame generation layer",
    "functions": {
      "vkGetInstanceProcAddr": "layer_vkGetInstanceProcAddr",
      "vkGetDeviceProcAddr": "layer_vkGetDeviceProcAddr"
    },
    "disable_environment": {
      "DISABLE_LSFG": "1"
    }
  }
}
EOF
echo -e "  ${GREEN}✓ Generated:${NC} ${MANIFEST_FILE}"

# 5. Setup default conf.toml
echo -e "\n${BLUE}[4/5] Setting up configuration (~/.config/lsfg-vk/conf.toml)...${NC}"
CONFIG_FILE="${CONFIG_DIR}/conf.toml"
if [[ ! -f "${CONFIG_FILE}" ]]; then
    cat > "${CONFIG_FILE}" << EOF
version = 1

[global]
dll = "${FOUND_DLL}"

[[game]]
exe = "mpv"

multiplier = 3
flow_scale = 1.0
performance_mode = false
hdr_mode = false
EOF
    echo -e "  ${GREEN}✓ Created:${NC} ${CONFIG_FILE}"
else
    echo -e "  ${GREEN}✓ Existing conf.toml preserved.${NC}"
fi

# 6. Install launcher binary
echo -e "\n${BLUE}[5/5] Installing 'lsfg' launcher script...${NC}"
cp -f "${SCRIPT_DIR}/bin/lsfg" "${INSTALL_BIN}/lsfg"
chmod +x "${INSTALL_BIN}/lsfg"
echo -e "  ${GREEN}✓ Installed to:${NC} ${INSTALL_BIN}/lsfg"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo -e "\n${YELLOW}Notice:${NC} Make sure ${BOLD}~/.local/bin${NC} is added to your shell PATH (in ~/.bashrc or ~/.zshrc):"
    echo -e "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# 7. Configure mpv
echo -e "\n${BLUE}[+] Checking mpv profile...${NC}"
MPV_CONF="${MPV_CONFIG_DIR}/mpv.conf"
if [[ -f "${MPV_CONF}" ]]; then
    if ! grep -q "\[lsfg\]" "${MPV_CONF}"; then
        echo -e "  Appending [lsfg] profile to ${MPV_CONF}..."
        cat >> "${MPV_CONF}" << 'EOF'

# ===== Profile: lsfg-vk (Lossless Scaling Frame Generation) =====
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
    cp "${SCRIPT_DIR}/config/mpv/mpv.conf" "${MPV_CONF}"
    echo -e "  ${GREEN}✓ Created ${MPV_CONF}${NC}"
fi

echo -e "\n${BOLD}${GREEN}✨ Setup completed successfully! ✨${NC}"
echo -e "You can now run:"
echo -e "  ${BOLD}lsfg mpv /path/to/video.mkv${NC}"
echo -e "  ${BOLD}lsfg -m 3 -f 1.0 mpv \"video.webm\"${NC}"
echo -e "  ${BOLD}lsfg yt \"https://www.youtube.com/watch?v=...\"${NC}\n"
