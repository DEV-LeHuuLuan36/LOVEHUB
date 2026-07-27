const fs = require('fs');
const path = 'd:\\Flutter_Source\\LOVEHUB\\lib\\features\\finance\\presentation\\screens\\finance_screen.dart';
let content = fs.readFileSync(path, 'utf8');

// Find ALL occurrences
const targets = ['expenseSoon', 'chartSoon', 'No jars yet', 'Tap "', 'finance.addToJar'];
for (const t of targets) {
    let idx = content.indexOf(t);
    if (idx >= 0) {
        console.log(`"${t}" FIRST at ${idx}: ${JSON.stringify(content.slice(idx, idx + 80))}`);
        // Check for more
        let count = 1;
        let next = idx + 1;
        while ((next = content.indexOf(t, next)) >= 0) {
            count++;
            console.log(`"${t}" ALSO at ${next}: ${JSON.stringify(content.slice(next, next + 80))}`);
            next++;
        }
        console.log(`Total occurrences of "${t}": ${count}`);
        console.log('---');
    } else {
        console.log(`"${t}": NOT FOUND`);
    }
}
