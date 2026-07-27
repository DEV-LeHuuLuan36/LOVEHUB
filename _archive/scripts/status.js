const fs = require('fs');
const path = 'd:\\Flutter_Source\\LOVEHUB\\lib\\features\\finance\\presentation\\screens\\finance_screen.dart';
let content = fs.readFileSync(path, 'utf8');

// Check all the target areas
const checks = [
    'jars.isEmpty',
    'No jars yet',
    'start saving',
    'label:',
    "finance.noJars",
    "finance.jarsCount",
    "finance.emptyHint",
    "finance.addToJar",
    "finance.expenseSoon",
    "finance.chartSoon",
    "finance.addBtn",
];

for (const c of checks) {
    const idx = content.indexOf(c);
    if (idx >= 0) {
        console.log(`[FOUND] "${c}" at ${idx}`);
        console.log(`  Context: ${JSON.stringify(content.slice(idx, idx + 80))}`);
    } else {
        console.log(`[MISSING] "${c}"`);
    }
}
