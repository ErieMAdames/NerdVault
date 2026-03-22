#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# NerdVault CMS - WSL (Ubuntu) Development Environment Bootstrap
#
# Installs Python 3.12, Node.js 20 (via nvm), git defaults, and pre-commit
# inside a WSL Ubuntu environment.
#
# This script is IDEMPOTENT -- running it multiple times is safe.
# Each step checks whether the tool is already present before installing.
#
# Usage:  chmod +x bootstrap-wsl.sh && ./bootstrap-wsl.sh
# ---------------------------------------------------------------------------

set -euo pipefail

# ---- helpers ---------------------------------------------------------------

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $1"; }
skip()  { echo -e "${GRAY}[SKIP]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()  { echo -e "${RED}[FAIL]${NC} $1"; }

declare -A SUMMARY

record() { SUMMARY["$1"]="$2"; }

print_summary() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  WSL BOOTSTRAP SUMMARY${NC}"
    echo -e "${CYAN}========================================${NC}"
    for key in "${!SUMMARY[@]}"; do
        val="${SUMMARY[$key]}"
        case "$val" in
            "Installed")       color="$GREEN"  ;;
            "Already present") color="$GRAY"   ;;
            *)                 color="$YELLOW" ;;
        esac
        echo -e "  ${color}${key}: ${val}${NC}"
    done
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

# ---- 1. system packages ----------------------------------------------------

info "Updating system packages (may ask for sudo password)..."
if sudo apt-get update -qq && sudo apt-get upgrade -y -qq; then
    ok "System packages updated."
else
    warn "Package update had issues. Continuing anyway."
fi

# ---- 2. Python 3.12 --------------------------------------------------------

if command -v python3.12 &>/dev/null; then
    skip "Python 3.12 already installed ($(python3.12 --version))."
    record "Python 3.12" "Already present"
else
    info "Installing Python 3.12..."
    if sudo apt-get install -y software-properties-common -qq && \
       sudo add-apt-repository -y ppa:deadsnakes/ppa && \
       sudo apt-get update -qq && \
       sudo apt-get install -y python3.12 python3.12-venv python3.12-dev -qq; then
        ok "Python 3.12 installed ($(python3.12 --version))."
        record "Python 3.12" "Installed"
    else
        fail "Could not install Python 3.12 via deadsnakes PPA."
        warn "Fallback: try 'sudo apt install python3' for your distro's default Python 3."
        record "Python 3.12" "FAILED"
    fi
fi

# Make sure pip is available for Python 3.12
if ! python3.12 -m pip --version &>/dev/null 2>&1; then
    info "Installing pip for Python 3.12..."
    sudo apt-get install -y python3-pip -qq 2>/dev/null || \
        python3.12 -m ensurepip --upgrade 2>/dev/null || \
        warn "Could not install pip automatically. Run: python3.12 -m ensurepip --upgrade"
fi

# ---- 3. nvm + Node.js 20 ---------------------------------------------------

export NVM_DIR="${HOME}/.nvm"

# Source nvm if it exists (may already be installed but not in this shell)
if [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck source=/dev/null
    source "$NVM_DIR/nvm.sh"
fi

if command -v nvm &>/dev/null; then
    skip "nvm already installed."
    record "nvm" "Already present"
else
    info "Installing nvm (Node Version Manager)..."
    if curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash; then
        export NVM_DIR="${HOME}/.nvm"
        # shellcheck source=/dev/null
        source "$NVM_DIR/nvm.sh"
        ok "nvm installed."
        record "nvm" "Installed"
    else
        fail "Could not install nvm."
        warn "Install manually: https://github.com/nvm-sh/nvm#installing-and-updating"
        record "nvm" "FAILED"
    fi
fi

if command -v nvm &>/dev/null; then
    NODE_20_INSTALLED=$(nvm ls 20 2>/dev/null | grep -c "v20" || true)
    if [ "$NODE_20_INSTALLED" -gt 0 ]; then
        skip "Node.js 20 already installed."
        record "Node.js 20" "Already present"
    else
        info "Installing Node.js 20 LTS..."
        if nvm install 20; then
            ok "Node.js 20 installed ($(node --version))."
            record "Node.js 20" "Installed"
        else
            fail "Could not install Node.js 20 via nvm."
            record "Node.js 20" "FAILED"
        fi
    fi
    nvm alias default 20 2>/dev/null || true
else
    warn "nvm not available -- skipping Node.js install."
    record "Node.js 20" "Skipped (nvm not available)"
fi

# ---- 4. git -----------------------------------------------------------------

if command -v git &>/dev/null; then
    skip "git already installed ($(git --version))."
    record "git" "Already present"
else
    info "Installing git..."
    if sudo apt-get install -y git -qq; then
        ok "git installed."
        record "git" "Installed"
    else
        fail "Could not install git."
        record "git" "FAILED"
    fi
fi

# Set recommended defaults (safe to re-run)
git config --global init.defaultBranch main 2>/dev/null || true
info "git default branch set to 'main'."

# ---- 5. pre-commit ---------------------------------------------------------

if command -v pre-commit &>/dev/null; then
    skip "pre-commit already installed ($(pre-commit --version))."
    record "pre-commit" "Already present"
else
    info "Installing pre-commit..."
    if python3.12 -m pip install --user pre-commit 2>/dev/null || \
       python3 -m pip install --user pre-commit 2>/dev/null || \
       pip install --user pre-commit 2>/dev/null; then
        ok "pre-commit installed."
        record "pre-commit" "Installed"

        # Ensure ~/.local/bin is on PATH for this session
        export PATH="$HOME/.local/bin:$PATH"

        # Add to .bashrc if not already there
        if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
            info "Added ~/.local/bin to PATH in .bashrc."
        fi
    else
        fail "Could not install pre-commit."
        warn "Try manually: pip install pre-commit"
        record "pre-commit" "FAILED"
    fi
fi

# ---- 6. summary -------------------------------------------------------------

print_summary

echo -e "${GREEN}NEXT STEPS:${NC}"
echo "  1. If this is your first time, launch Ubuntu from the Start menu to set"
echo "     your Linux username and password."
echo "  2. Open VS Code on Windows and install the 'WSL' extension."
echo "  3. In VS Code, press Ctrl+Shift+P -> 'WSL: Connect to WSL'."
echo "  4. Open a terminal in VS Code -- you're now coding in Linux!"
echo "  5. Start Phase 1 of the INSTRUCTIONS.md."
echo ""
echo "  To verify everything works, run:"
echo "    python3.12 --version"
echo "    node --version"
echo "    git --version"
echo "    docker --version      (requires Docker Desktop running on Windows)"
echo "    pre-commit --version"
echo ""
