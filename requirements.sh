#!/usr/bin/env bash
# requirements.sh — One-script setup for the entire Samvit project
# Usage: chmod +x requirements.sh && ./requirements.sh
set -e

echo "========================================"
echo "  Samvit — Full Environment Setup"
echo "========================================"

# ── 1. System packages ──────────────────────────────────────────
echo ""
echo "[1/5] Installing system dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
    python3 python3-pip python3-venv \
    openjdk-21-jdk \
    cmake build-essential \
    libi2c-dev \
    git curl unzip wget

# ── 2. Python dependencies (backend + HIL simulation) ────────────
echo ""
echo "[2/5] Installing Python dependencies..."
pip3 install --quiet \
    fastapi \
    uvicorn \
    google-generativeai \
    pydantic \
    numpy

# ── 3. Android SDK + Gradle (Kotlin app) ─────────────────────────
echo ""
echo "[3/5] Setting up Android SDK..."
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

if [ -z "$ANDROID_HOME" ]; then
    export ANDROID_HOME="$HOME/android-sdk"
fi

if [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
    mkdir -p "$ANDROID_HOME"
    cd "$ANDROID_HOME"
    wget -q "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -O cmdline-tools.zip
    unzip -q cmdline-tools.zip
    mkdir -p cmdline-tools/latest
    mv cmdline-tools/bin cmdline-tools/lib cmdline-tools/latest/ 2>/dev/null || true
    rm -f cmdline-tools.zip
    echo "Android command-line tools installed."
else
    echo "Android SDK already present, skipping download."
fi

export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

yes | sdkmanager --licenses > /dev/null 2>&1 || true
sdkmanager --install \
    "platform-tools" \
    "platforms;android-36" \
    "build-tools;36.0.0" 2>&1 | tail -3

# ── 4. Build the Android app ─────────────────────────────────────
echo ""
echo "[4/5] Building Android app..."
cd "$(dirname "$0")"
echo "sdk.dir=$ANDROID_HOME" > local.properties

if [ ! -f ".env" ]; then
    cp .env.example .env
    echo "Created .env from .env.example — edit it to add your GEMINI_API_KEY."
fi

export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
./gradlew assembleDebug --quiet 2>&1 && echo "APK built: app/build/outputs/apk/debug/app-debug.apk" || echo "Build failed — check errors above."

# ── 5. Verify HIL simulation ─────────────────────────────────────
echo ""
echo "[5/5] Running hardware-in-loop simulation..."
python3 hardware/tests/hil_simulation.py 2>&1 | tail -5

# ── Done ──────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo "  Setup complete!"
echo ""
echo "  Android APK:  app/build/outputs/apk/debug/app-debug.apk"
echo "  Backend:      cd backend && python3 main.py"
echo "  HIL tests:    python3 hardware/tests/hil_simulation.py --verbose"
echo ""
echo "  NOTE: Edit .env and set GEMINI_API_KEY before running the backend."
echo "  NOTE: Place google-services.json in app/ for Firebase features."
echo "========================================"
