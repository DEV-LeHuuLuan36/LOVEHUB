const fs = require('fs');
const path = 'd:\\Flutter_Source\\LOVEHUB\\lib\\features\\finance\\presentation\\screens\\finance_screen.dart';
let content = fs.readFileSync(path, 'utf8');

// Find the exact bytes for the "No jars yet" line
const target = 'No jars yet';
const idx = content.indexOf(target);
console.log('Byte positions:', idx, 'to', idx + 100);
const slice = content.slice(idx, idx + 100);
console.log('Raw slice repr:', JSON.stringify(slice));
// Print each char
console.log('Char-by-char:');
for (let i = 0; i < 60; i++) {
    const cp = slice.codePointAt(i);
    if (cp > 127 || cp === 39 || cp === 34) { // non-ascii or quote
        process.stdout.write(`[${i}] U+${cp.toString(16).toUpperCase().padStart(4,'0')} "${slice[i]}"  `);
    }
}
console.log('\n---');
// Try different replacements
const tests = [
    "? 'No jars yet - tap \"+ New Jar\" to start'",
    "? 'No jars yet — tap \"+ New Jar\" to start'",
    "? 'No jars yet — tap \"+ New Jar\" to start'",
];
for (const t of tests) {
    console.log(`Test "${t}":`, content.includes(t));
}
