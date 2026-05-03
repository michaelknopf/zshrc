# Android SDK tooling.
# Android Studio installs the SDK under ~/Library/Android/sdk by default on macOS.
# Exposing platform-tools (adb, fastboot) and emulator on PATH lets us invoke
# them without qualifying full paths, which matters for scripts and adb workflows.

export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"  # older tools still read this name

if [[ -d "$ANDROID_HOME" ]]; then
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
fi
