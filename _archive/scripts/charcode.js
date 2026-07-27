const fs = require('fs');
const path = 'd:\\Flutter_Source\\LOVEHUB\\lib\\features\\finance\\presentation\\screens\\finance_screen.dart';
let content = fs.readFileSync(path, 'utf8');

// expenseSoon line
let idx = content.indexOf('expenseSoon');
let lineStart = content.lastIndexOf('\n', idx);
let lineEnd = content.indexOf('\n', idx);
let line = content.slice(lineStart + 1, lineEnd);
console.log('expenseSoon line:', JSON.stringify(line));

// chartSoon line  
idx = content.indexOf('chartSoon');
lineStart = content.lastIndexOf('\n', idx);
lineEnd = content.indexOf('\n', idx);
line = content.slice(lineStart + 1, lineEnd);
console.log('chartSoon line:', JSON.stringify(line));

// Print each char code
console.log('\nchartSoon char codes:');
for (let i = 0; i < line.length; i++) {
    const cp = line.codePointAt(i);
    console.log(`  [${i}] U+${cp.toString(16).toUpperCase().padStart(4,'0')} = "${line[i]}"`);
}
