const fs = require('fs');
const path = 'd:\\Flutter_Source\\LOVEHUB\\lib\\features\\finance\\presentation\\screens\\finance_screen.dart';
let content = fs.readFileSync(path, 'utf8');
let changed = 0;

// Fix 1: _SummaryCard ternary
// File has: "? 'No jars yet - tap "+ New Jar" to start'\r\n                : 'finance.jarsCount'..."
const emDash = '\u2014';
const lq = '\u201C';
const rq = '\u201D';
const old1 = "? 'No jars yet" + emDash + " tap " + lq + "+ New Jar" + rq + " to start'\r\n                : 'finance.jarsCount'.tr(namedArgs: {'count': '${jars.length}'}),";
const new1 = "? 'finance.noJars'.tr()\r\n                : 'finance.jarsCount'.tr(namedArgs: {'count': '${jars.length}'}),";
if (content.includes(old1)) {
    content = content.replace(old1, new1);
    changed++;
    console.log('[OK] _SummaryCard: replaced with finance.noJars');
} else {
    console.log('[FAIL] SummaryCard pattern not found');
    process.exit(1);
}

// Fix 2: _EmptyJarsHint
const old2 = "Text(\r\n            'Tap " + lq + "+ New Jar" + rq + " to start saving together.',";
const new2 = "Text(\r\n            'finance.emptyHint'.tr(),";
if (content.includes(old2)) {
    content = content.replace(old2, new2);
    changed++;
    console.log('[OK] _EmptyJarsHint: replaced with finance.emptyHint');
} else {
    console.log('[FAIL] EmptyJarsHint pattern not found');
    process.exit(1);
}

// Fix 3: expenseSoon - remove the leading quote before tr()
const old3 = "''finance.expenseSoon'.tr()}";
const new3 = "'${'finance.expenseSoon'.tr()}";
if (content.includes(old3)) {
    content = content.replace(old3, new3);
    changed++;
    console.log('[OK] _ExpenseSplitPlaceholder: fixed expenseSoon');
} else {
    console.log('[FAIL] expenseSoon pattern not found');
    process.exit(1);
}

// Fix 4: chartSoon - remove the leading quote before tr() and fix closing
const old4 = "'📊 'finance.chartSoon'.tr()";
const new4 = "'📊 ${'finance.chartSoon'.tr()}'";
if (content.includes(old4)) {
    content = content.replace(old4, new4);
    changed++;
    console.log('[OK] _ExpenseChartPlaceholder: fixed chartSoon');
} else {
    console.log('[FAIL] chartSoon pattern not found');
    process.exit(1);
}

fs.writeFileSync(path, content, 'utf8');
console.log(`Done. ${changed} changes.`);
