import * as fs from 'fs';
import * as path from 'path';
import { hapTasks } from '@ohos/hvigor-ohos-plugin';

// LocalConfig.ets is gitignored (per-developer backend URL/key). Create it from the template so a fresh
// clone builds — in the terminal and in DevEco alike.
const commonDir: string = path.resolve(__dirname, 'src/main/ets/common');
const localConfig: string = path.join(commonDir, 'LocalConfig.ets');
if (!fs.existsSync(localConfig)) {
    fs.copyFileSync(path.join(commonDir, 'LocalConfig.example.ets'), localConfig);
}

export default {
    system: hapTasks,  /* Built-in plugin of Hvigor. It cannot be modified. */
    plugins:[]         /* Custom plugin to extend the functionality of Hvigor. */
}
