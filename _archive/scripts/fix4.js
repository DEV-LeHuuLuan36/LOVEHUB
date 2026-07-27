const fs = require('fs');
const path = 'd:\\Flutter_Source\\LOVEHUB\\lib\\features\\finance\\presentation\\screens\\finance_screen.dart';
let content = fs.readFileSync(path, 'utf8');

// Fix 1: _SummaryCard - em-dash + curly double quotes
// Actual: "? 'No jars yet — tap "+ New Jar" to start'"
const old1 = "? 'No jars yet\u2014 tap \u201c+ New Jar\u201d to start'";
const new1 = "? 'finance.noJars'.tr()";
if (content.includes(old1)) {
    content = content.replace(old1, new1);
    console.log('[OK] Replaced summary card empty text');
} else {
    console.log('[FAIL] Could not find target string');
    process.exit(1);
}

// Fix 2: _EmptyJarsHint - curly quotes around + New Jar
const old2 = 'Tap "\u201c+ New Jar\u201d to start saving together.';
const new2 = "'finance.emptyHint'.tr()";
if (content.includes(old2)) {
    content = content.replace(old2, new2);
    console.log('[OK] Replaced empty hint text');
} else {
    console.log('[FAIL] Could not find empty hint string');
    process.exit(1);
}

// Fix 3: _JarCard - 'Add' button (has ➕ emoji)
const old3 = "label: 'Add'";
const new3 = "label: 'finance.addToJar'.tr()";
if (content.includes(old3)) {
    content = content.replace(old3, new3);
    console.log('[OK] Replaced Add button');
} else {
    console.log('[FAIL] Could not find Add button');
    process.exit(1);
}

fs.writeFileSync(path, content, 'utf8');
console.log('All done.');
