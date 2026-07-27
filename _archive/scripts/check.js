const fs = require('fs');
const path = 'd:\\Flutter_Source\\LOVEHUB\\lib\\features\\finance\\presentation\\screens\\finance_screen.dart';
let content = fs.readFileSync(path, 'utf8');

// Verify all patterns before fixing
const checks = [
    ['expenseSoon', content.indexOf('expenseSoon')],
    ['chartSoon', content.indexOf('chartSoon')],
    ['EmptyJarsHint', content.indexOf('Tap "')],
    ['SummaryCard', content.indexOf('No jars yet')],
];

for (const [name, idx] of checks) {
    if (idx >= 0) {
        console.log(`${name} at ${idx}: ${JSON.stringify(content.slice(idx, idx + 80))}`);
    }
}
