import * as fs from 'fs';
import * as path from 'path';
import { hapTasks } from '@ohos/hvigor-ohos-plugin';

// LocalConfig.ets is gitignored (per-developer backend URL/key). Create it from the template so a fresh
// clone builds - in the terminal and in DevEco alike.
const commonDir: string = path.resolve(__dirname, 'src/main/ets/common');
const localConfig: string = path.join(commonDir, 'LocalConfig.ets');
const template: string = fs.readFileSync(path.join(commonDir, 'LocalConfig.example.ets'), 'utf8');
if (!fs.existsSync(localConfig)) {
    fs.writeFileSync(localConfig, template);
} else {
    // The template gains fields over time; an older LocalConfig.ets would then fail to compile. Add the missing
    // fields with the template's (empty) defaults and leave the developer's own values untouched.
    const field: RegExp = /^\s*static readonly (\w+):.*;\s*$/gm;
    const current: string = fs.readFileSync(localConfig, 'utf8');
    const missing: string[] = [];
    let match: RegExpExecArray | null = field.exec(template);
    while (match !== null) {
        if (!new RegExp('static readonly ' + match[1] + '\\b').test(current)) {
            missing.push(match[0].replace(/\s+$/, ''));
        }
        match = field.exec(template);
    }
    const end: number = current.lastIndexOf('}');
    if (missing.length > 0 && end >= 0) {
        fs.writeFileSync(localConfig, current.slice(0, end) + missing.join('\n') + '\n' + current.slice(end));
    }
}

export default {
    system: hapTasks,  /* Built-in plugin of Hvigor. It cannot be modified. */
    plugins:[]         /* Custom plugin to extend the functionality of Hvigor. */
}
