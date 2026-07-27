import sys

path = r'd:\Flutter_Source\LOVEHUB\lib\features\finance\presentation\screens\finance_screen.dart'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix 1: _SummaryCard - "No jars yet — tap "+ New Jar" to start"
# em-dash = U+2014, left-double-quote = U+201C, right-double-quote = U+201D
old1 = "? 'No jars yet" + "\u2014" + " tap " + "\u201c" + "+ New Jar" + "\u201d" + " to start'"
new1 = "? 'finance.noJars'.tr()"
if old1 in content:
    content = content.replace(old1, new1)
    print('[OK] Replaced summary empty-state text')
else:
    # Debug
    idx = content.find('jars.isEmpty')
    print('[DEBUG] Around jars.isEmpty:')
    print(repr(content[idx:idx+120]))
    sys.exit(1)

# Fix 2: _EmptyJarsHint - "Tap "+ New Jar" to start saving together."
old2 = 'Tap "\u201c+ New Jar\u201d to start saving together.'
new2 = "'finance.emptyHint'.tr()"
if old2 in content:
    content = content.replace(old2, new2)
    print('[OK] Replaced empty hint text')
else:
    idx = content.find('start saving')
    print('[DEBUG] Around "start saving":')
    print(repr(content[idx-5:idx+80]))
    sys.exit(1)

# Fix 3: _JarCard - 'Add' button
old3 = "label: 'Add'"
new3 = "label: 'finance.addToJar'.tr()"
if old3 in content:
    content = content.replace(old3, new3)
    print('[OK] Replaced Add button label')
else:
    idx = content.find('Add')
    print('[DEBUG] Around "Add":')
    print(repr(content[idx-20:idx+20]))
    sys.exit(1)

# Fix 4: _ExpenseSplitPlaceholder - "Expense tracking is coming soon" (already done via PS)
# Already fixed

# Fix 5: _ExpenseChartPlaceholder (already done via PS)
# Already fixed

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('All done.')
