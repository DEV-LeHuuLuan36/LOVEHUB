const fs = require('fs');
const path = 'd:\\Flutter_Source\\LOVEHUB\\lib\\features\\finance\\presentation\\screens\\finance_screen.dart';
let content = fs.readFileSync(path, 'utf8');
let changed = 0;

// Fix 1: _SummaryCard ternary - old hardcoded text -> finance.noJars
// The old text has: em-dash U+2014, curly quotes U+201C/U+201D
const old1 = "? 'No jars yet\u2014 tap \u201c+ New Jar\u201d to start'";
const new1 = "? 'finance.noJars'.tr()";
if (content.includes(old1)) {
    content = content.replace(old1, new1);
    changed++;
    console.log('[OK] _SummaryCard: replaced old text with finance.noJars');
} else {
    // The string might be on one line - find it
    const idx = content.indexOf('No jars yet');
    if (idx >= 0) {
        console.log('[DEBUG] "No jars yet" at', idx, ':', JSON.stringify(content.slice(idx, idx + 100)));
    }
}

// Fix 2: _EmptyJarsHint - Tap "+ New Jar"...
const old2 = 'Tap "\u201c+ New Jar\u201d to start saving together.';
const new2 = "'finance.emptyHint'.tr()";
if (content.includes(old2)) {
    content = content.replace(old2, new2);
    changed++;
    console.log('[OK] _EmptyJarsHint: replaced with finance.emptyHint');
} else {
    const idx = content.indexOf('start saving');
    if (idx >= 0) {
        console.log('[DEBUG] "start saving" at', idx, ':', JSON.stringify(content.slice(idx - 5, idx + 80)));
    }
}

// Fix 3: _JarCard - 'Add' button
const old3 = "label: '\u2795 Add'";
const new3 = "label: 'finance.addToJar'.tr()";
if (content.includes(old3)) {
    content = content.replace(old3, new3);
    changed++;
    console.log('[OK] _JarCard: replaced Add button with finance.addToJar');
} else {
    const idx = content.indexOf("label: '");
    if (idx >= 0) {
        console.log('[DEBUG] label at', idx, ':', JSON.stringify(content.slice(idx, idx + 30)));
    }
}

// Fix 4: _ExpenseSplitPlaceholder - broken tr() call
// Current: ''finance.expenseSoon'.tr()} 💕',
// Should be: '${'finance.expenseSoon'.tr()} 💕',
const old4 = "''finance.expenseSoon'.tr()}";
const new4 = "'${'finance.expenseSoon'.tr()}";
if (content.includes(old4)) {
    content = content.replace(old4, new4);
    changed++;
    console.log('[OK] _ExpenseSplitPlaceholder: fixed expenseSoon tr()');
} else {
    const idx = content.indexOf('expenseSoon');
    if (idx >= 0) {
        console.log('[DEBUG] expenseSoon at', idx, ':', JSON.stringify(content.slice(idx - 5, idx + 60)));
    }
}

// Fix 5: _ExpenseChartPlaceholder - broken tr() call
// Current: '📊 'finance.chartSoon'.tr()},'
// Should be: '📊 ${'finance.chartSoon'.tr()}',
const old5 = "'📊 'finance.chartSoon'.tr()";
const new5 = "'📊 ${'finance.chartSoon'.tr()}'";
if (content.includes(old5)) {
    content = content.replace(old5, new5);
    changed++;
    console.log('[OK] _ExpenseChartPlaceholder: fixed chartSoon tr()');
} else {
    const idx = content.indexOf('chartSoon');
    if (idx >= 0) {
        console.log('[DEBUG] chartSoon at', idx, ':', JSON.stringify(content.slice(idx - 5, idx + 60)));
    }
}

if (changed === 0) {
    console.log('[WARN] No changes made!');
    process.exit(1);
}

fs.writeFileSync(path, content, 'utf8');
console.log(`Done. ${changed} changes made.`);
