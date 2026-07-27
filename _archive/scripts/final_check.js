const fs = require('fs');

// Validate JSONs
let ok = true;
try { JSON.parse(fs.readFileSync('d:\\Flutter_Source\\LOVEHUB\\assets\\translations\\en.json', 'utf8')); console.log('en.json: valid'); }
catch(e) { console.log('en.json: INVALID -', e.message); ok = false; }
try { JSON.parse(fs.readFileSync('d:\\Flutter_Source\\LOVEHUB\\assets\\translations\\vi.json', 'utf8')); console.log('vi.json: valid'); }
catch(e) { console.log('vi.json: INVALID -', e.message); ok = false; }

// Check diary_screen for remaining hardcoded English
const diary = fs.readFileSync('d:\\Flutter_Source\\LOVEHUB\\lib\\features\\diary\\presentation\\screens\\diary_screen.dart', 'utf8');
const badPatterns = [
    "'All \\u2728'", "'Try selecting", "'Add Memory'", "'No memories in",
    "'Error loading memories'", "'Tap \"Add Memory\""
];
for (const s of badPatterns) {
    if (diary.includes(s)) {
        const idx = diary.indexOf(s);
        console.log(`[WARN] ${JSON.stringify(s)} found at ${idx}`);
    }
}

// Verify key usages
const checks = [
    ['memory.filterAll', diary], ['memory.emptyInYear', diary], ['memory.filterAllHint', diary],
    ['memory.addHint', diary], ['memory.errorLoading', diary],
];
for (const [key, text] of checks) {
    console.log(`${key}: ${text.includes(`'${key}'.tr()`) ? 'OK' : 'MISSING'}`);
}
