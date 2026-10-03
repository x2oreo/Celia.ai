# Source this before running build tools from a terminal: `source watch/env.sh`
DEVECO=/Applications/DevEco-Studio.app/Contents
export DEVECO_SDK_HOME="$DEVECO/sdk"
export PATH="$DEVECO/tools/hvigor/bin:$DEVECO/tools/ohpm/bin:$DEVECO/tools/node/bin:$DEVECO/sdk/default/openharmony/toolchains:$PATH"
