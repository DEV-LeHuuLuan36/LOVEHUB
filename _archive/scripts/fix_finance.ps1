$path = 'd:\Flutter_Source\LOVEHUB\lib\features\finance\presentation\screens\finance_screen.dart'
$c = Get-Content $path -Raw

# Fix 1: _SummaryCard - "No jars yet..." -> finance.noJars
# File uses Unicode curly quotes: U+201C ("), U+2019 ('), U+201D (")
$old1 = "? 'No jars yet" + [char]0x2014 + " tap " + [char]0x201C + "+ New Jar" + [char]0x201D + " to start'"
$new1 = "? 'finance.noJars'.tr()"
if ($c.Contains($old1)) {
    $c = $c.Replace($old1, $new1)
    Write-Host "[OK] Replaced summary empty-state text"
} else {
    Write-Host "[SKIP] Could not find old string for summary empty-state"
    # Try to find what's there
    $idx = $c.IndexOf("jars.isEmpty")
    Write-Host "Context: $($c.Substring($idx, 80))"
}

# Fix 2: _EmptyJarsHint - "Tap "+ New Jar"..." -> finance.emptyHint
$old2 = '"Tap " + [char]0x201C + "+ New Jar" + [char]0x201D + " to start saving together."'
$new2 = "'finance.emptyHint'.tr()"
if ($c.Contains('Tap "')) {
    $c = $c.Replace('Tap "+ New Jar" to start saving together.', "'finance.emptyHint'.tr()")
    Write-Host "[OK] Replaced empty hint text"
} else {
    Write-Host "[SKIP] Could not find empty hint text"
}

# Fix 3: _JarCard - "Add" button -> finance.addToJar
if ($c.Contains("label: 'Add'")) {
    $c = $c.Replace("label: 'Add'", "label: 'finance.addToJar'.tr()")
    Write-Host "[OK] Replaced Add button label"
} else {
    Write-Host "[SKIP] Could not find Add button label"
}

# Fix 4: _ExpenseSplitPlaceholder - "Expense tracking is coming soon" -> finance.expenseSoon
if ($c.Contains('Expense tracking is coming soon')) {
    $c = $c.Replace('Expense tracking is coming soon', "'finance.expenseSoon'.tr()")
    Write-Host "[OK] Replaced expense tracking text"
} else {
    Write-Host "[SKIP] Could not find expense tracking text"
}

# Fix 5: _ExpenseChartPlaceholder - chart text
if ($c.Contains('Charts will appear here once expense tracking is enabled')) {
    $c = $c.Replace('Charts will appear here once expense tracking is enabled.', "'finance.chartSoon'.tr()")
    Write-Host "[OK] Replaced chart placeholder text"
} else {
    Write-Host "[SKIP] Could not find chart placeholder text"
}

# Fix 6: _JarCard - MoMo emoji button label stays as is (emoji + MoMo, not hardcoded English)

Set-Content -Path $path -Value $c -NoNewline
Write-Host "Done. File written."
