const fs = require('fs');
const path = 'd:\\Flutter_Source\\LOVEHUB\\lib\\features\\finance\\presentation\\screens\\finance_screen.dart';
let content = fs.readFileSync(path, 'utf8');
let changed = 0;

// Fix 1: _SummaryCard ternary - multiline with \r\n
// The file has: "? 'No jars yet - tap "+ New Jar" to start'\r\n                : ..."
// em-dash U+2014, but use raw char
const emDash = '\u2014'; // —
const lq = '\u201C';     // "
const rq = '\u201D';     // "
const old1 = "? 'No jars yet" + emDash + " tap " + lq + "+ New Jar" + rq + " to start'\r\n                : 'finance.jarsCount'.tr(namedArgs: {'count': '${jars.length}'}),";
const new1 = "? 'finance.noJars'.tr()\r\n                : 'finance.jarsCount'.tr(namedArgs: {'count': '${jars.length}'}),";
if (content.includes(old1)) {
    content = content.replace(old1, new1);
    changed++;
    console.log('[OK] _SummaryCard: replaced with finance.noJars');
} else {
    // Try without em-dash
    const idx = content.indexOf('No jars yet');
    console.log('[DEBUG] "No jars yet" raw:', JSON.stringify(content.slice(idx, idx + 100)));
}

// Fix 2: _EmptyJarsHint - ASCII double quotes around + New Jar
const old2 = 'Tap "' + lq + '+ New Jar' + rq + ' to start saving together.';
const new2 = "'finance.emptyHint'.tr()";
if (content.includes(old2)) {
    content = content.replace(old2, new2);
    changed++;
    console.log('[OK] _EmptyJarsHint: replaced with finance.emptyHint');
} else {
    const idx = content.indexOf('start saving');
    if (idx >= 0) {
        console.log('[DEBUG] "start saving":', JSON.stringify(content.slice(idx - 40, idx + 60)));
    }
    // Also try with ASCII double quote
    const old2b = 'Tap "' + '+ New Jar" to start saving together.';
    if (content.includes(old2b)) {
        console.log('[FOUND] ASCII version');
        content = content.replace(old2b, new2);
        changed++;
        console.log('[OK] _EmptyJarsHint: replaced with finance.emptyHint (ASCII)');
    }
}

// Fix 3: _JarCard - 'Add' button (ALREADY DONE by fix5.js)
console.log('Add button check:', content.includes("label: 'finance.addToJar'.tr()"));

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
        console.log('[DEBUG] expenseSoon:', JSON.stringify(content.slice(idx - 5, idx + 60)));
    }
}

// Fix 5: _ExpenseChartPlaceholder - broken tr() call
// Current: '📊 'finance.chartSoon'.tr()},'
// Should be: '📊 ${'finance.chartSoon'.tr()},'
const old5 = "'📊 'finance.chartSoon'.tr()";
const new5 = "'📊 ${'finance.chartSoon'.tr()}'";
if (content.includes(old5)) {
    content = content.replace(old5, new5);
    changed++;
    console.log('[OK] _ExpenseChartPlaceholder: fixed chartSoon tr()');
} else {
    const idx = content.indexOf('chartSoon');
    if (idx >= 0) {
        console.log('[DEBUG] chartSoon:', JSON.stringify(content.slice(idx - 5, idx + 60)));
    }
}

fs.writeFileSync(path, content, 'utf8');
console.log(`Done. ${changed} changes.`);
