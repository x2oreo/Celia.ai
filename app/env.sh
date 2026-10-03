# Source this before running build/device commands from a terminal:  source app/env.sh
# Uses the toolchain bundled with DevEco Studio (hvigor, ohpm, node, hdc). Override DEVECO if installed elsewhere.
DEVECO="${DEVECO:-/Applications/DevEco-Studio.app/Contents}"
export DEVECO_SDK_HOME="$DEVECO/sdk"
export PATH="$DEVECO/tools/hvigor/bin:$DEVECO/tools/ohpm/bin:$DEVECO/tools/node/bin:$DEVECO/sdk/default/openharmony/toolchains:$PATH"
