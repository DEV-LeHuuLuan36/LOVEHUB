const fs = require('fs');
const path = 'd:\\Flutter_Source\\LOVEHUB\\lib\\features\\finance\\presentation\\screens\\finance_screen.dart';
let content = fs.readFileSync(path, 'utf8');

// Find all non-ASCII chars near the target line
const target = 'No jars yet';
const idx = content.indexOf(target);
if (idx < 0) { console.log('Target not found'); process.exit(1); }
const chunk = content.slice(idx - 5, idx + 80);
console.log('Raw chars near target:');
for (let i = 0; i < chunk.length; i++) {
    const ch = chunk[i];
    const cp = chunk.codePointAt(i);
    if (cp > 127) {
        console.log(`  pos ${i}: U+${cp.toString(16).toUpperCase().padStart(4,'0')} "${ch}"`);
    }
}
// Also show the line
const lineStart = content.lastIndexOf('\n', idx - 1) + 1;
const lineEnd = content.indexOf('\n', idx);
console.log('\nFull line:');
console.log(JSON.stringify(content.slice(lineStart, lineEnd)));
