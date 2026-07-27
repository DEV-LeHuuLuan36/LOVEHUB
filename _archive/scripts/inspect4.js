const fs = require('fs');
const path = 'd:\\Flutter_Source\\LOVEHUB\\lib\\features\\finance\\presentation\\screens\\finance_screen.dart';
let content = fs.readFileSync(path, 'utf8');

// Find the expenseSoon line
let idx = 0;
let count = 0;
while ((idx = content.indexOf('expenseSoon', idx)) >= 0) {
    const lineStart = content.lastIndexOf('\n', idx);
    const lineEnd = content.indexOf('\n', idx);
    const line = content.slice(lineStart, lineEnd);
    console.log(`Occurrence ${++count} at byte ${idx}:`);
    console.log('Raw line:', JSON.stringify(line));
    // Print char codes
    const relIdx = idx - lineStart;
    console.log('Chars around match:');
    for (let i = Math.max(0, relIdx - 20); i < Math.min(line.length, relIdx + 40); i++) {
        const cp = line.codePointAt(i);
        const display = cp > 127 || cp === 39 || cp === 34 || cp === 123 || cp === 125
            ? `U+${cp.toString(16).toUpperCase().padStart(4,'0')} "${line[i]}"` 
            : `"${line[i]}"`;
        process.stdout.write(`[${i}] ${display}  `);
    }
    console.log('\n---');
    idx++;
}

// Find chartSoon line
idx = 0;
count = 0;
while ((idx = content.indexOf('chartSoon', idx)) >= 0) {
    const lineStart = content.lastIndexOf('\n', idx);
    const lineEnd = content.indexOf('\n', idx);
    const line = content.slice(lineStart, lineEnd);
    console.log(`chartSoon occurrence ${++count} at byte ${idx}:`);
    console.log('Raw line:', JSON.stringify(line));
    idx++;
}
