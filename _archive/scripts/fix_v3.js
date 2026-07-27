const fs = require('fs');
const path = 'd:\\Flutter_Source\\LOVEHUB\\lib\\features\\finance\\presentation\\screens\\finance_screen.dart';
let content = fs.readFileSync(path, 'utf8');
let changed = 0;

function replaceExact(oldStr, newStr, label) {
    if (content.includes(oldStr)) {
        content = content.replace(oldStr, newStr);
        changed++;
        console.log(`[OK] ${label}`);
        return true;
    } else {
        // Debug: find where the old string might be
        const idx = content.indexOf('No jars yet');
        if (idx >= 0) {
            console.log(`[FAIL] ${label}`);
            console.log(`  File has: ${JSON.stringify(content.slice(idx, idx + 80))}`);
        } else {
            console.log(`[FAIL] ${label} - not found`);
        }
        return false;
    }
}

// From charcode.js analysis:
// expenseSoon: ' ${'finance.expenseSoon'.tr()} 💕',  (CORRECT)
// chartSoon:   '📊 ${'finance.chartSoon'.tr()}',      (MISSING 💕)
// _SummaryCard ternary (multiline):
//   "? 'No jars yet — tap "+ New Jar" to start'\r\n                : 'finance.jarsCount'.tr(...)"
// _EmptyJarsHint:
//   "Tap "+ New Jar" to start saving together."

// Fix 1: _SummaryCard - full ternary (both branches)
const old1 = "? 'No jars yet\u2014 tap \u201c+ New Jar\u201d to start'\r\n                : 'finance.jarsCount'.tr(namedArgs: {'count': '${jars.length}'}),";
const new1 = "? 'finance.noJars'.tr()\r\n                : 'finance.jarsCount'.tr(namedArgs: {'count': '${jars.length}'}),";
replaceExact(old1, new1, '_SummaryCard');

// Fix 2: _EmptyJarsHint - hardcoded text with curly quotes
const old2 = "Tap \u201c+ New Jar\u201d to start saving together.";
const new2 = "'finance.emptyHint'.tr()";
replaceExact(old2, new2, '_EmptyJarsHint');

// Fix 3: chartSoon - insert 💕 emoji (U+1F495) before trailing quote
const old3 = "${'finance.chartSoon'.tr()}',";
const new3 = "${'finance.chartSoon'.tr()} \u1f495',";
replaceExact(old3, new3, 'chartSoon emoji');

// Fix 4: _JarCard Add button
if (content.includes("label: 'finance.addToJar'.tr()")) {
    console.log('[OK] _JarCard Add button already localized');
} else {
    content = content.replace("label: '\u2795 Add'", "label: 'finance.addToJar'.tr()");
    changed++;
    console.log('[OK] _JarCard Add button localized');
}

fs.writeFileSync(path, content, 'utf8');
console.log(`\nDone. ${changed} changes written.`);
