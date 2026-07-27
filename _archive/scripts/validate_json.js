const fs = require('fs');
try {
    JSON.parse(fs.readFileSync('d:\\Flutter_Source\\LOVEHUB\\assets\\translations\\en.json', 'utf8'));
    console.log('en.json: valid JSON');
} catch(e) {
    console.log('en.json: INVALID -', e.message);
}
try {
    JSON.parse(fs.readFileSync('d:\\Flutter_Source\\LOVEHUB\\assets\\translations\\vi.json', 'utf8'));
    console.log('vi.json: valid JSON');
} catch(e) {
    console.log('vi.json: INVALID -', e.message);
}
