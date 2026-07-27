const fs = require('fs');
const path = 'd:\\Flutter_Source\\LOVEHUB\\lib\\features\\finance\\presentation\\screens\\finance_screen.dart';
let content = fs.readFileSync(path, 'utf8');

const idx = content.indexOf('No jars yet');
console.log('Context around "No jars yet":');
console.log(JSON.stringify(content.slice(idx - 5, idx + 100)));

// Find the full ternary line including the em-dash
const emDash = '\u2014';
const lq = '\u201C';
const rq = '\u201D';
const test1 = "? 'No jars yet" + emDash + " tap " + lq + "+ New Jar" + rq + " to start'";
console.log('\nTest string:');
console.log(JSON.stringify(test1));

// Check if em-dash is in file at the right spot
const idx2 = content.indexOf(emDash, idx - 5);
console.log('\nEm-dash at:', idx2, 'vs idx:', idx);
if (idx2 >= 0) {
    console.log('Context:', JSON.stringify(content.slice(idx2 - 5, idx2 + 10)));
}

// Try building the exact file string from scratch
const afterNoJars = content.slice(idx, idx + 80);
console.log('\nAfter "No jars yet":');
for (let i = 0; i < 80; i++) {
    const cp = afterNoJars.codePointAt(i);
    if (cp > 127 || cp === 39 || cp === 10 || cp === 13) {
        process.stdout.write(`[${i}] U+${cp.toString(16).toUpperCase().padStart(4,'0')} "${afterNoJars[i]}"  `);
    }
}
console.log('\nDone');
