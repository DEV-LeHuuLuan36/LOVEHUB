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
        const idx = content.indexOf(oldStr.slice(0, 30));
        if (idx >= 0) {
            console.log(`[FAIL] ${label} - near-match: ${JSON.stringify(content.slice(idx, idx + oldStr.length + 10))}`);
        } else {
            console.log(`[FAIL] ${label} - not found at all`);
        }
        return false;
    }
}

// Fix 1: _SummaryCard - the exact hardcoded string
const old1a = "? 'No jars yet\u2014 tap \u201c+ New Jar\u201d to start'";
const new1a = "? 'finance.noJars'.tr()";
replaceExact(old1a, new1a, '_SummaryCard hardcoded text');

// Fix 2: _EmptyJarsHint - Tap "+ New Jar"...
const old2a = "Tap \u201c+ New Jar\u201d to start saving together.";
const new2a = "'finance.emptyHint'.tr()";
replaceExact(old2a, new2a, '_EmptyJarsHint hardcoded text');

// Fix 3: chartSoon - missing 💕 emoji
const old3a = "${'finance.chartSoon'.tr()}',";
const new3a = "${'finance.chartSoon'.tr()} \u1f495',";
replaceExact(old3a, new3a, 'chartSoon missing emoji');

// Fix 4: _JarCard - 'Add' button (check if already done)
if (content.includes("label: 'finance.addToJar'.tr()")) {
    console.log('[OK] _JarCard Add button already localized');
} else if (content.includes("label: '\u2795 Add'")) {
    content = content.replace("label: '\u2795 Add'", "label: 'finance.addToJar'.tr()");
    changed++;
    console.log('[OK] _JarCard Add button localized');
} else {
    console.log('[WARN] _JarCard Add button - checking...');
    const idx = content.indexOf("label:");
    if (idx >= 0) console.log('[DEBUG] label at:', JSON.stringify(content.slice(idx, idx + 40)));
}

fs.writeFileSync(path, content, 'utf8');
console.log(`\nDone. ${changed} changes written.`);
