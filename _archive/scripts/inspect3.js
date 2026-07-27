const fs = require('fs');
const path = 'd:\\Flutter_Source\\LOVEHUB\\lib\\features\\finance\\presentation\\screens\\finance_screen.dart';
let content = fs.readFileSync(path, 'utf8');

// Get 120 chars before and after expenseSoon
const idx = content.indexOf('expenseSoon');
console.log('=== expenseSoon context ===');
console.log('Before (50):', JSON.stringify(content.slice(idx - 50, idx)));
console.log('Match:', JSON.stringify(content.slice(idx, idx + 60)));
console.log('After (50):', JSON.stringify(content.slice(idx + 60, idx + 110)));

// Also chartSoon
const idx2 = content.indexOf('chartSoon');
console.log('\n=== chartSoon context ===');
console.log('Before (50):', JSON.stringify(content.slice(idx2 - 50, idx2)));
console.log('Match:', JSON.stringify(content.slice(idx2, idx2 + 60)));
console.log('After (50):', JSON.stringify(content.slice(idx2 + 60, idx2 + 110)));

// Print exact bytes of expenseSoon line
const lineStart = content.lastIndexOf('\n', idx - 1) + 1;
const lineEnd = content.indexOf('\n', idx);
console.log('\n=== Full expenseSoon line ===');
const line = content.slice(lineStart, lineEnd);
console.log(JSON.stringify(line));
console.log('Visual:', line);
