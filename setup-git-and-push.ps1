# setup-git-and-push.ps1
# Usage:
#   .\setup-git-and-push.ps1 -Remote "https://github.com/USER/REPO.git"

param(
  [Parameter(Mandatory = $true)]
  [string]$Remote
)

$ErrorActionPreference = "Stop"
Set-Location -Path (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Write-TextFile {
  param([string]$Path, [string]$Content)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $Content | Set-Content -Encoding UTF8 -Path $Path
}

# ---------- .gitignore ----------
$gitignore = @"
# Node / TypeScript
node_modules/
dist/
build/
coverage/
*.log
npm-debug.log*
pnpm-debug.log*
yarn-debug.log*
yarn-error.log*
*.tsbuildinfo

# Env files
.env
.env.*
!.env.example

# Prisma cache / sqlite (if any)
backend/node_modules/.prisma/
backend/prisma/dev.db
backend/prisma/*.db-journal

# Frontend caches
frontend/.vite/
frontend/.next/
.vite/

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Generated
frontend/public/*.pdf
"@
if (-not (Test-Path ".gitignore")) {
  Write-TextFile -Path ".gitignore" -Content $gitignore
}

# ---------- .env.example from backend/.env ----------
if (Test-Path "./backend/.env" -and -not (Test-Path "./backend/.env.example")) {
  $lines = Get-Content "./backend/.env"
  $masked = foreach ($l in $lines) {
    if ($l -match '^\s*#') { $l }
    elseif ($l -match '^\s*$') { $l }
    elseif ($l -match '^\s*([^=]+)\s*=\s*(.*)$') { "$($matches[1])=***" }
    else { $l }
  }
  Write-TextFile -Path "./backend/.env.example" -Content ($masked -join "`r`n")
}

# ---------- Git LFS (optional) ----------
$hasLfs = $false
try {
  git lfs version | Out-Null
  $hasLfs = $true
} catch {
  $hasLfs = $false
}
if ($hasLfs) {
  git lfs install | Out-Null
  if (-not (Test-Path ".gitattributes")) {
@"
*.xlsx filter=lfs diff=lfs merge=lfs -text
*.pdf  filter=lfs diff=lfs merge=lfs -text
*.png  filter=lfs diff=lfs merge=lfs -text
*.jpg  filter=lfs diff=lfs merge=lfs -text
"@ | Set-Content -Encoding UTF8 ".gitattributes"
  }
}

# ---------- Init git ----------
if (-not (Test-Path ".git")) {
  git init -b main | Out-Null
}

# Basic identity if not set
try {
  $n = (git config user.name) 2>$null
  $e = (git config user.email) 2>$null
  if (-not $n) { git config user.name  "Santy" | Out-Null }
  if (-not $e) { git config user.email "you@example.com" | Out-Null }
} catch { }

# Never track .env even if added manually
if (Test-Path "./backend/.env")  { git update-index --assume-unchanged "./backend/.env"  2>$null }
if (Test-Path "./frontend/.env") { git update-index --assume-unchanged "./frontend/.env" 2>$null }

# ---------- Commit and push ----------
git add -A

$commitCount = 0
try { $commitCount = [int]((git rev-list --count HEAD)) } catch { $commitCount = 0 }

if ($commitCount -eq 0) {
  git commit -m "Initial commit" | Out-Null
} else {
  git commit -m "Sync project state" | Out-Null
}

if ((git remote) -notcontains "origin") {
  git remote add origin $Remote | Out-Null
} else {
  git remote set-url origin $Remote | Out-Null
}

git push -u origin main
Write-Host ""
Write-Host "Done. Pushed to $Remote (branch main)." -ForegroundColor Green
Write-Host "Check that backend/.env is NOT in the repo. Use backend/.env.example to share variable names." -ForegroundColor Yellow
