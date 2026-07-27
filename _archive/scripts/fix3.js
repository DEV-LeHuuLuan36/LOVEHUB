const fs = require('fs');
const path = 'd:\\Flutter_Source\\LOVEHUB\\lib\\features\\finance\\presentation\\screens\\finance_screen.dart';
let content = fs.readFileSync(path, 'utf8');

// Fix 1: _SummaryCard - replace the exact 3-line block
// Find: "? 'No jars yet — tap "+ New Jar" to start'"
// Replace: "? 'finance.noJars'.tr()"
const old1 = "? 'No jars yet\u2014 tap \u201c+ New Jar\u201d to start'";
const new1 = "? 'finance.noJars'.tr()";
if (content.includes(old1)) {
    content = content.replace(old1, new1);
    console.log('[OK] Replaced summary card empty text');
} else {
    // Try with regular dash
    const old1b = "? 'No jars yet - tap \"+ New Jar\" to start'";
    if (content.includes(old1b)) {
        content = content.replace(old1b, new1);
        console.log('[OK] Replaced summary card empty text (alt dash)');
    } else {
        // Search for what we actually have
        const idx = content.indexOf('No jars yet');
        if (idx >= 0) {
            console.log('[DEBUG] Found "No jars yet" at byte', idx);
            console.log('Actual:', JSON.stringify(content.slice(idx, idx + 80)));
        } else {
            console.log('[DEBUG] "No jars yet" not found at all');
            console.log('Searching for "jars.isEmpty"...');
            const idx2 = content.indexOf('jars.isEmpty');
            console.log('Found at:', idx2, JSON.stringify(content.slice(idx2, idx2 + 120)));
        }
    }
}

// Fix 2: _EmptyJarsHint - Tap "+ New Jar" to start saving together.
const old2 = 'Tap "\u201c+ New Jar\u201d to start saving together.';
const new2 = "'finance.emptyHint'.tr()";
if (content.includes(old2)) {
    content = content.replace(old2, new2);
    console.log('[OK] Replaced empty hint text');
} else {
    const idx = content.indexOf('start saving');
    if (idx >= 0) {
        console.log('[DEBUG] start saving:', JSON.stringify(content.slice(idx - 5, idx + 80)));
    }
}

// Fix 3: _JarCard - 'Add' button
const old3 = "label: 'Add'";
const new3 = "label: 'finance.addToJar'.tr()";
if (content.includes(old3)) {
    content = content.replace(old3, new3);
    console.log('[OK] Replaced Add button');
} else {
    const idx = content.indexOf("label: 'Add'");
    if (idx < 0) {
        // Try 'Add' without quotes
        const idx2 = content.indexOf("'Add'");
        if (idx2 >= 0) {
            console.log('[DEBUG] Found Add:', JSON.stringify(content.slice(idx2 - 20, idx2 + 20)));
        } else {
            console.log('[DEBUG] Add not found');
        }
    }
}

// Fix 4: MoMo button label - just the emoji stays, remove MoMo text
// Actually let's keep it as-is per original (emoji + MoMo)
// Fix 5: _ExpenseSplitPlaceholder - fix the "💕" to go AFTER tr()
// Already done above via str_replace, check if still broken
if (content.includes("''finance.expenseSoon'.tr()")) {
    console.log('[WARN] expenseSoon still has double-quotes issue');
}

fs.writeFileSync(path, content, 'utf8');
console.log('Done. File written.');
