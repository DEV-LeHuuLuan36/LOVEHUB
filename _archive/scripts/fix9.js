const fs = require('fs');
const path = 'd:\\Flutter_Source\\LOVEHUB\\lib\\features\\finance\\presentation\\screens\\finance_screen.dart';
let content = fs.readFileSync(path, 'utf8');
let changed = 0;

// Fix 1: _SummaryCard - em-dash + curly quotes around + New Jar
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

// Fix 3: chartSoon - broken closing quote placement
// Current (broken): '📊 ${'finance.chartSoon'.tr()}',
// Correct:          '📊 ${'finance.chartSoon'.tr()}',
// The trailing , is after } but the opening ' for '📊 ' was consumed by tr() key
// So: remove the stray ' after tr() and add it after 📊
const old3 = "'📊 ${'finance.chartSoon'.tr()}'" + "',\r";
const new3 = "'📊 ${'finance.chartSoon'.tr()}'" + "',\r";
// Actually the issue is: the trailing ', makes it: ...tr()}',
// We need: ...tr()}', (emoji before trailing ')
// The current: '📊 ${'finance.chartSoon'.tr()}',
// The correct: '📊 ${'finance.chartSoon'.tr()}'💕',
// Wait let me re-examine. The expenseSoon line is:
// ' ${'finance.expenseSoon'.tr()} 💕',
// And chartSoon is:
// '📊 ${'finance.chartSoon'.tr()}',
// The difference: expenseSoon has the emoji INSIDE the string (space emoji quote comma)
// chartSoon has: ...tr()}', (no emoji, just close brace, close paren, quote, comma)
// Wait no! The expenseSoon has `${...} 💕` and the chartSoon has `${...}`
// The chartSoon is MISSING the 💕 emoji!
//
// Looking at the file state:
// expenseSoon: '${'finance.expenseSoon'.tr()} 💕',
// chartSoon: '📊 ${'finance.chartSoon'.tr()',
//            The chartSoon has a stray closing ' for the opening '📊 '
//            that was consumed by the '${' nested key quote
// The fix for chartSoon: remove the stray ' after tr() and add emoji
// Fix: insert 💕 emoji between tr()} and ',
const broken3 = "${'finance.chartSoon'.tr()}',";
const fixed3 = "${'finance.chartSoon'.tr()}" + "💕',";
if (content.includes(broken3)) {
    content = content.replace(broken3, fixed3);
    changed++;
    console.log('[OK] chartSoon: inserted missing emoji');
} else {
    console.log('[FAIL] chartSoon pattern not found');
    // Debug
    const idx = content.indexOf('chartSoon');
    console.log('[DEBUG]', JSON.stringify(content.slice(idx - 10, idx + 60)));
    process.exit(1);
}

fs.writeFileSync(path, content, 'utf8');
console.log(`Done. ${changed} changes.`);
