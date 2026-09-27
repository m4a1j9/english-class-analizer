param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$Targets,
    # Override auto-detection if the Requester in info.txt is not the learner.
    [string]$Learner = '',
    # Regenerate outputs that already exist.
    [switch]$Force
)

# ================= Settings =================
# Model for the analysis pass. opus / sonnet / haiku, or a full model id.
$Model = 'opus'
# Attempts per analysis before giving up.
$MaxAttempts = 2
# ============================================

# claude.exe speaks UTF-8. Windows PowerShell decodes a native program's stdout
# using the console codepage, which is OEM (866 here) when launched from the .bat
# -- that turns every em dash into "тАФ". Pin both directions to UTF-8 so the
# result does not depend on how the script was started.
$utf8NoBom              = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding           = $utf8NoBom

$root      = Split-Path -Parent $MyInvocation.MyCommand.Path
$promptDir = Join-Path $root 'prompts'
$knownFile = Join-Path $promptDir 'known-phrases.md'
# Words/phrases already learned via anki-auto: { "phrase": timesSeen, ... }
$learnedFile = Join-Path (Split-Path -Parent $root) 'learned.json'

Write-Host ''
Write-Host '  === Lesson analysis : tutor phrases + learner corrections ===' -ForegroundColor Cyan
Write-Host ''

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host '  claude CLI not found on PATH. Install Claude Code first.' -ForegroundColor Red
    exit 1
}

# --- Resolve the folder -----------------------------------------------------
if (-not $Targets -or $Targets.Count -eq 0) {
    . (Join-Path $root '_FolderPicker.ps1')
    $sel = Select-RecordingFolder
    if (-not $sel) {
        Write-Host '  No folder selected. Nothing to do.' -ForegroundColor Yellow
        Write-Host ''
        exit 0
    }
    $Targets = @($sel)
}

$folders = @($Targets | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) })
if ($folders.Count -eq 0) {
    Write-Host '  Nothing valid to process. Drop a recording folder on the .bat.' -ForegroundColor Red
    Write-Host ''
    exit 1
}

# --- Helpers ----------------------------------------------------------------

function Get-CleanTranscript {
    param([string]$Path)
    $lines = Get-Content -LiteralPath $Path -Encoding UTF8
    $stripped = $lines | ForEach-Object { $_ -replace '^\[[\d:.]+\s*-->\s*[\d:.]+\]\s*', '' }
    $text = ($stripped -join ' ') -replace '\s+', ' '
    return $text.Trim()
}

function Get-KnownSection {
    if (-not (Test-Path -LiteralPath $script:knownFile)) { return '' }
    $known = (Get-Content -LiteralPath $script:knownFile -Raw -Encoding UTF8).Trim()
    # Ignore the comment header so an untouched dictionary counts as empty.
    $body = ($known -split "`n" | Where-Object { $_ -notmatch '^\s*(#|<!--|$)' }) -join "`n"
    if (-not $body.Trim()) { return '' }
    return @"


# Already learned - do not output these again

The learner has already studied everything below. Treat it as a blocklist: never
include one of these as an entry, and do not include a near-duplicate that teaches
the same point. Spend the slots on material that is new to him.

$known
"@
}

function Get-LearnedSection {
    if (-not (Test-Path -LiteralPath $script:learnedFile)) { return '' }
    try {
        $bank = Get-Content -LiteralPath $script:learnedFile -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        Write-Host "  warning: could not parse learned.json, ignoring it" -ForegroundColor Yellow
        return ''
    }
    $items = @($bank.PSObject.Properties.Name | Where-Object { $_ -and $_.Trim() } |
               ForEach-Object { $_.Trim().ToLower() } | Sort-Object -Unique)
    if ($items.Count -eq 0) { return '' }
    $list = ($items | ForEach-Object { "- $_" }) -join "`n"
    return @"


# Vocabulary already learned - never output these

The learner has already learned every word and phrase below. Do not make any of them
an entry, in any form: ignore case, inflection (*dissect* / *dissecting*) and small
wording changes. A longer phrase is still allowed only if its new part is the thing
being taught, not a learned word. Every entry in the output must be new to him.

$list
"@
}

function Invoke-Analysis {
    param([string]$PromptFile, [string]$Speaker, [string]$Date, [string]$Transcript, [string]$ErrLog,
          [switch]$UseLearned)

    $instructions = Get-Content -LiteralPath $PromptFile -Raw -Encoding UTF8
    $learned = ''
    if ($UseLearned) { $learned = Get-LearnedSection }
    $payload = @"
$instructions$(Get-KnownSection)$learned

# This lesson

Speaker: $Speaker
Date: $Date

---BEGIN TRANSCRIPT---
$Transcript
---END TRANSCRIPT---
"@

    # Hand the payload over as a file so nothing depends on pipe encoding, and
    # keep stderr so a failure can say why instead of just "failed".
    $payloadFile = [IO.Path]::GetTempFileName()
    [IO.File]::WriteAllText($payloadFile, $payload, $script:utf8NoBom)
    try {
        $out = & cmd /c "type `"$payloadFile`" | claude -p --model $script:Model 2`>`"$ErrLog`""
        $code = $LASTEXITCODE
    }
    finally {
        Remove-Item -LiteralPath $payloadFile -Force -ErrorAction SilentlyContinue
    }

    $text = ($out -join "`n").Trim()
    if ($code -ne 0) { return @{ Ok = $false; Reason = "claude exited with code $code"; Text = $text } }
    if (-not $text) { return @{ Ok = $false; Reason = 'claude returned no output'; Text = '' } }

    # Strip a wrapping code fence if the model added one.
    $text = $text -replace '^```(?:markdown)?\r?\n', ''
    $text = $text -replace '\r?\n```$', ''
    return @{ Ok = $true; Reason = ''; Text = $text.Trim() }
}

# --- Process each folder ----------------------------------------------------

foreach ($folder in $folders) {
    $name = Split-Path $folder -Leaf
    Write-Host "  Folder : $name"

    $info = Join-Path $folder 'info.txt'
    $date = ''
    $requester = ''
    if (Test-Path -LiteralPath $info) {
        foreach ($line in (Get-Content -LiteralPath $info -Encoding UTF8)) {
            if ($line -match '^Requester:\s*(.+?)(#|\s*\()') { $requester = $Matches[1].Trim() }
            if ($line -match '^Start time:\s*(\d{4}-\d{2}-\d{2})')  { $date = $Matches[1] }
        }
    }
    if (-not $date) { $date = (Get-Item -LiteralPath $folder).LastWriteTime.ToString('yyyy-MM-dd') }
    if ($Learner) { $requester = $Learner }

    $txts = @(Get-ChildItem -LiteralPath $folder -Filter '*.txt' -File |
              Where-Object { $_.Name -ne 'info.txt' })

    if ($txts.Count -lt 2) {
        Write-Host "  Need two transcript .txt files, found $($txts.Count). Skipping." -ForegroundColor Yellow
        Write-Host ''
        continue
    }

    # Speaker name is the filename minus any leading "N-" track number.
    $learnerFile = $txts | Where-Object { ($_.BaseName -replace '^\d+-', '') -eq $requester } | Select-Object -First 1
    if (-not $learnerFile) {
        Write-Host "  Could not tell who the learner is (Requester: '$requester')." -ForegroundColor Yellow
        Write-Host "  Re-run with:  -Learner <name matching a .txt filename>" -ForegroundColor Yellow
        Write-Host ''
        continue
    }
    $tutorFile = $txts | Where-Object { $_.FullName -ne $learnerFile.FullName } | Select-Object -First 1

    $learnerName = $learnerFile.BaseName -replace '^\d+-', ''
    $tutorName   = $tutorFile.BaseName   -replace '^\d+-', ''
    Write-Host "  Date   : $date"
    Write-Host "  Learner: $learnerName    Tutor: $tutorName"

    $outDir = Join-Path $folder 'output'
    if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

    $jobs = @(
        @{ Prompt = 'tutor-phrases.md';       File = $tutorFile;   Speaker = $tutorName;   Out = "phrases-$tutorName-$date.md";      Label = 'tutor phrases';       UseLearned = $true },
        @{ Prompt = 'learner-corrections.md'; File = $learnerFile; Speaker = $learnerName; Out = "corrections-$learnerName-$date.md"; Label = 'learner corrections'; UseLearned = $false }
    )

    foreach ($job in $jobs) {
        $target = Join-Path $outDir $job.Out
        if ((Test-Path -LiteralPath $target) -and (-not $Force)) {
            Write-Host "  skip   : $($job.Out) (exists, use -Force)" -ForegroundColor DarkGray
            continue
        }

        $promptFile = Join-Path $promptDir $job.Prompt
        if (-not (Test-Path -LiteralPath $promptFile)) {
            Write-Host "  missing prompt: $($job.Prompt)" -ForegroundColor Red
            continue
        }

        $transcript = Get-CleanTranscript -Path $job.File.FullName
        $words = ($transcript -split '\s+').Count

        $errLog  = [IO.Path]::GetTempFileName()
        $result  = $null
        for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
            $suffix = ''
            if ($attempt -gt 1) { $suffix = " retry $($attempt - 1)" }
            Write-Host "  run    : $($job.Label) ($words words)$suffix ..." -NoNewline

            $result = Invoke-Analysis -PromptFile $promptFile -Speaker $job.Speaker `
                                      -Date $date -Transcript $transcript -ErrLog $errLog `
                                      -UseLearned:$job.UseLearned
            if ($result.Ok) { break }

            Write-Host " failed - $($result.Reason)" -ForegroundColor Red
            $stderr = @(Get-Content -LiteralPath $errLog -ErrorAction SilentlyContinue |
                        Where-Object { $_.Trim() } | Select-Object -Last 4)
            foreach ($l in $stderr) { Write-Host "           $l" -ForegroundColor DarkYellow }
            if ($result.Text) { Write-Host "           output began: $($result.Text.Substring(0, [Math]::Min(120, $result.Text.Length)))" -ForegroundColor DarkYellow }
        }
        Remove-Item -LiteralPath $errLog -Force -ErrorAction SilentlyContinue

        if (-not $result.Ok) {
            Write-Host "  give up: $($job.Out) not written" -ForegroundColor Red
            continue
        }

        # WriteAllText, not Set-Content: PS 5.1 -Encoding utf8 prepends a BOM,
        # which shows up as a stray glyph at the top of the markdown.
        [IO.File]::WriteAllText($target, $result.Text, $utf8NoBom)
        Write-Host " -> output\$($job.Out)" -ForegroundColor Green
    }

    Write-Host ''
}

Write-Host '  Done.' -ForegroundColor Green
Write-Host ''
