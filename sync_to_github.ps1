# sync_to_github.ps1
# Beast Feast / Daggerheart GM Screen -- commit & push the tools in this
# folder (Generatory: Kuznia_Bestii.html, Arena_Bestii.html,
# Beast_Feast_Adversaries_Environments.xlsx, ...) to GitHub.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File "sync_to_github.ps1"
#
# Run it from (or point it at) the "Generatory" folder -- NOT the parent
# "Beast Feast" vault folder, which also holds the campaign notes and the
# huge rulebook PDFs that must never end up in this repo.

# NOTE: deliberately NOT $ErrorActionPreference = "Stop". PowerShell turns
# a native command's stderr output (routine git status text like "Switched
# to a new branch", or expected non-zero exits like `git remote get-url
# origin` when no remote exists yet) into a terminating exception when
# ErrorActionPreference is "Stop" - which would abort this script on
# completely normal git output. Instead we check $LASTEXITCODE ourselves
# wherever a failure actually needs to stop the script.
$ErrorActionPreference = "Continue"
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$RepoUrl = "git@github.com:iKuro1337/Daggerheart-GM-Screen.git"
$Branch  = "main"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

function Fail($msg) {
    Write-Host "BLAD: $msg" -ForegroundColor Red
    exit 1
}

# --- sanity: is git available? ---
git --version *> $null
if ($LASTEXITCODE -ne 0) {
    Fail "git nie jest zainstalowany albo nie jest w PATH."
}

# --- make sure we never accidentally commit huge/unrelated files ---
if (-not (Test-Path ".gitignore")) {
    @"
# OS / editor junk
Thumbs.db
.DS_Store
*.tmp

# scratch space some sync tools use
tmp/
"@ | Set-Content -Encoding UTF8 ".gitignore"
    Write-Host "Utworzono .gitignore"
}

# --- init repo if this folder isn't one yet ---
if (-not (Test-Path ".git")) {
    Write-Host "Brak repo git w tym folderze - inicjalizuje..."
    git init | Out-Null
    git checkout -b $Branch 2>$null
    git remote add origin $RepoUrl
    Write-Host "Zainicjalizowano repo i ustawiono origin -> $RepoUrl"
} else {
    $existingRemote = git remote get-url origin 2>$null
    if (-not $existingRemote) {
        git remote add origin $RepoUrl
        Write-Host "Ustawiono origin -> $RepoUrl"
    } elseif ($existingRemote -ne $RepoUrl) {
        Write-Host "UWAGA: origin wskazuje na inne repo ($existingRemote) niz oczekiwane ($RepoUrl). Nie zmieniam automatycznie - sprawdz recznie." -ForegroundColor Yellow
    }
}

# --- guard against giant files slipping in (e.g. someone drops a PDF here) ---
$bigFiles = git ls-files --others --exclude-standard --cached |
    Where-Object { Test-Path $_ } |
    ForEach-Object { Get-Item $_ } |
    Where-Object { $_.Length -gt 25MB }
if ($bigFiles) {
    Write-Host "UWAGA: znaleziono plik(i) > 25 MB, ktore nie powinny raczej trafic do repo:" -ForegroundColor Yellow
    $bigFiles | ForEach-Object { Write-Host "  - $($_.FullName) ($([math]::Round($_.Length/1MB,1)) MB)" -ForegroundColor Yellow }
    Write-Host "Kontynuuje mimo to - jesli to pomylka, przerwij (Ctrl+C) i popraw .gitignore." -ForegroundColor Yellow
}

git add -A

$status = git status --porcelain
if (-not $status) {
    Write-Host "Brak zmian do wyslania."
    exit 0
}

Write-Host "Zmiany do commita:"
git status --short

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
git commit -m "Aktualizacja narzedzi Beast Feast ($timestamp)" | Out-Null

git push -u origin $Branch
if ($LASTEXITCODE -ne 0) {
    Fail "push nie powiodl sie (mozliwy konflikt z origin/$Branch, brak dostepu SSH, albo repo jeszcze nie istnieje na GitHubie). Sprobuj recznie 'git pull --rebase origin $Branch' albo sprawdz dostep SSH ('ssh -T git@github.com')."
}

Write-Host "Gotowe - zmiany wyslane na GitHub ($RepoUrl, branch $Branch)." -ForegroundColor Green
