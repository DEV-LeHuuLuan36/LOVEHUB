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
        const idx = content.indexOf('No jars yet');
        if (idx >= 0) console.log(`[FAIL] ${label}: ${JSON.stringify(content.slice(idx, idx + 80))}`);
        return false;
    }
}

// File has: "yet — tap" (space EM-DASH space)
// charcode confirmed: [11]=space, [12]=EM-DASH, [13]=space
const emDash = '\u2014';
const lq = '\u201C';
const rq = '\u201D';
// Correct: 'No jars yet — tap "+ New Jar" to start'
const old1 = "? 'No jars yet " + emDash + " tap " + lq + "+ New Jar" + rq + " to start'\r\n                : 'finance.jarsCount'.tr(namedArgs: {'count': '${jars.length}'}),";
const new1 = "? 'finance.noJars'.tr()\r\n                : 'finance.jarsCount'.tr(namedArgs: {'count': '${jars.length}'}),";
replaceExact(old1, new1, '_SummaryCard');

fs.writeFileSync(path, content, 'utf8');
console.log(`Done. ${changed} changes written.`);
