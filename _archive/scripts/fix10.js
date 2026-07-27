const fs = require('fs');
const path = 'd:\\Flutter_Source\\LOVEHUB\\lib\\features\\finance\\presentation\\screens\\finance_screen.dart';
let content = fs.readFileSync(path, 'utf8');
let changed = 0;

// Fix 1: _SummaryCard - em-dash + curly double quotes + \r\n
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
    console.log('[FAIL] _SummaryCard pattern not found');
    process.exit(1);
}

// Fix 2: _EmptyJarsHint - tap "+ New Jar" to start saving
const old2 = "Text(\r\n            'Tap " + lq + "+ New Jar" + rq + " to start saving together.',";
const new2 = "Text(\r\n            'finance.emptyHint'.tr(),";
if (content.includes(old2)) {
    content = content.replace(old2, new2);
    changed++;
    console.log('[OK] _EmptyJarsHint: replaced with finance.emptyHint');
} else {
    console.log('[FAIL] _EmptyJarsHint pattern not found');
    process.exit(1);
}

// Fix 3: chartSoon - broken interpolation closing
// Current: '📊 ${'finance.chartSoon'.tr()}',
// The ' after tr()} is a stray quote that closes the '📊 ' string prematurely.
// The emoji is MISSING from chartSoon. The correct line should be:
// '📊 ${'finance.chartSoon'.tr()} 💕',
// The fix: replace "tr()}'," with "tr()} 💕',"
const old3 = "${'finance.chartSoon'.tr()}',";
const new3 = "${'finance.chartSoon'.tr()} 💕',";
if (content.includes(old3)) {
    content = content.replace(old3, new3);
    changed++;
    console.log('[OK] chartSoon: inserted missing emoji');
} else {
    console.log('[FAIL] chartSoon pattern not found');
    const idx = content.indexOf('chartSoon');
    console.log('[DEBUG]', JSON.stringify(content.slice(idx - 5, idx + 60)));
    process.exit(1);
}

fs.writeFileSync(path, content, 'utf8');
console.log(`Done. ${changed} changes.`);
