const fs = require('fs');
const path = 'd:\\Flutter_Source\\LOVEHUB\\lib\\features\\finance\\presentation\\screens\\finance_screen.dart';
let content = fs.readFileSync(path, 'utf8');
let changed = 0;

// Fix 1: _SummaryCard - em-dash + curly double quotes + multiline
// The actual file has em-dash, curly quotes around + New Jar, and \r\n before the colon
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
    console.log('  Looking for:', JSON.stringify(old1));
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

// Fix 3: _ExpenseSplitPlaceholder - trailing emoji/spaces OUTSIDE string
// Current: '${'finance.expenseSoon'.tr()} 💕',
// Should be: '${'finance.expenseSoon'.tr()} 💕',
// The fix: add a closing single quote after 💕
const old3 = "${'finance.expenseSoon'.tr()} 💕',";
const new3 = "${'finance.expenseSoon'.tr()} 💕',";
// Find the exact string
const idx3 = content.indexOf("expenseSoon'.tr()}");
if (idx3 >= 0) {
    const before = content.slice(0, idx3);
    const after = content.slice(idx3);
    // after starts with "expenseSoon'.tr()}"
    // We want: "expenseSoon'.tr()} 💕',"
    // But currently it's: "expenseSoon'.tr()} 💕',"
    // So we need to insert a quote after the space
    // Find "💕'," and replace with "💕',"
    // Hmm, let me look at what's there
    const afterSnippet = after.slice(0, 40);
    console.log('[DEBUG] expenseSoon after:', JSON.stringify(afterSnippet));
    // The fix: change ".tr()} 💕'," to ".tr()} 💕'," 
    // That's: close brace, space, emoji, single quote, comma
    // But currently: close brace, space, emoji, single quote, comma
    // Wait, the difference is the closing quote for the string!
    // Current: ...tr()} 💕', 
    // That's: .tr()} space emoji ' ,
    // The string starts with '${' so we need a closing ' after 💕
    // The current code has ...tr()} 💕', which means: .tr()} space emoji ' ,
    // But the opening quote was consumed by the '${...} part
    // So the correct string should be: '${'finance.expenseSoon'.tr()} 💕'
    // That is: '${'finance.expenseSoon'.tr()} space emoji '
    // Currently: '${'finance.expenseSoon'.tr()} 💕' (missing closing ' before 💕)
    // Wait no...
    // Let me look at the actual characters
    // The line is: '${'finance.expenseSoon'.tr()} 💕',
    // Position 0: ' (string open)
    // Position 1-2: ${ (interp start)
    // Position 3: ' (key open)
    // ...
    // At the end: }' 💕',  or  } 💕',
    // Let me just find and fix the exact pattern
    // The pattern: "'${'finance.expenseSoon'.tr()} 💕',"  (wrong)
    // Should be:    "'${'finance.expenseSoon'.tr()} 💕',"  (correct)
    // Hmm these look the same! Let me be more precise...
    // The broken text is: ${'finance.expenseSoon'.tr()} 💕' 
    // (missing ' before 💕)
    // Fix: insert ' after the closing brace of tr()}
    const brokenPattern = "${'finance.expenseSoon'.tr()} 💕'";
    const fixedPattern = "${'finance.expenseSoon'.tr()} 💕'";
    // These are the same visually! Let me look at the char codes
    // Actually the problem is the single quote position
    // In the broken: '${'finance.expenseSoon'.tr()} 💕'
    // The ' before 💕 is the closing quote for the outer string
    // But we need that ' to be AFTER the emoji, not before
    // So the broken is: '${'finance.expenseSoon'.tr()} 💕' 
    // The correct is: '${'finance.expenseSoon'.tr()} 💕'
    // The ' should come AFTER 💕 not before it
    // Current chars: tr()} space 💕 ' ,
    // Should be: tr()} space 💕 ' ,
    // These ARE the same! Unless...
    // The current broken is: .tr()} 💕', (no quote after emoji)
    // No wait - I need to look at the raw bytes more carefully
    // Let me search for the exact string
    const search1 = ".tr()}";
    const pos1 = content.indexOf(search1);
    if (pos1 >= 0) {
        console.log('[DEBUG] .tr()} at', pos1, ':', JSON.stringify(content.slice(pos1, pos1 + 20)));
    }
}

// Fix 3: Simply insert a ' after 💕 in the expenseSoon line
// The exact broken string is: ${'finance.expenseSoon'.tr()} 💕' 
// (where the ' is BEFORE 💕)
// The fix: insert a ' between tr()} and  💕
// Wait no - let me just use a simple regex replacement
const re3 = /\$\{'finance\.expenseSoon'\.tr\}\}\s+💕'/g;
if (re3.test(content)) {
    content = content.replace(re3, "${'finance.expenseSoon'.tr()} 💕'");
    changed++;
    console.log('[OK] expenseSoon: inserted missing quote after emoji');
} else {
    // Try to find what's there
    const idx = content.indexOf('expenseSoon');
    const snippet = content.slice(idx - 30, idx + 50);
    console.log('[DEBUG] expenseSoon snippet:', JSON.stringify(snippet));
}

// Fix 4: chartSoon - similar issue
const re4 = /'📊 \$\{'finance\.chartSoon'\.tr\}\}/g;
if (re4.test(content)) {
    content = content.replace(re4, "'📊 ${'finance.chartSoon'.tr()}'");
    changed++;
    console.log('[OK] chartSoon: inserted missing quotes');
} else {
    const idx = content.indexOf('chartSoon');
    const snippet = content.slice(idx - 30, idx + 50);
    console.log('[DEBUG] chartSoon snippet:', JSON.stringify(snippet));
}

fs.writeFileSync(path, content, 'utf8');
console.log(`Done. ${changed} changes.`);
