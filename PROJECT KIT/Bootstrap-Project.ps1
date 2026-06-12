# ============================================================
#  Bootstrap-Project.ps1 — Claude Code Project Kit installer
#
#  HOW TO USE: copy the whole "PROJECT KIT" folder into your
#  project's ROOT folder, then double-click Bootstrap-Project.bat.
#  No editing required — the project root is auto-detected as the
#  PARENT of the folder this script lives in.
#
#  What it installs / configures (all steps are SAFE TO RE-RUN —
#  existing files are never overwritten, only missing pieces are
#  added, and the CLAUDE.md managed block is updated in place):
#    1. PROJECT KNOWLEDGE\ doc skeleton (only missing files created)
#    2. CLAUDE.md standing directives (managed BEGIN/END block)
#    3. REMOTE START\ phone-access launcher
#    4. git init + starter .gitignore (if missing)
#    5. Initial commit of the bootstrap files
#    6. GitHub remote: via gh CLI (creates a private repo, name
#       prompted) or a manually pasted repo URL
#    7. Repo URL recorded in PROJECT KNOWLEDGE\04-HANDOFF.md
#    8. Push
#
#  Works on stock Windows PowerShell 5.1. One-time GitHub CLI
#  setup ("gh auth login"): see README.md in this folder.
# ============================================================

# ---- optional knobs (defaults work for the setup above) ----
# How many folders UP from this script is the project root?
#   1 = kit lives in a subfolder of the project root (recommended)
#   0 = kit files sit directly in the project root itself
$LevelsUp = 1
# Hard override: set a full path here to ignore auto-detection entirely:
$ManualProjectPath = ""
# Default branch name for new repos:
$DefaultBranch = "main"
# ------------------------------------------------------------

$ErrorActionPreference = "Stop"

function Fail($msg) {
  Write-Host ""
  Write-Host "  ERROR: $msg" -ForegroundColor Red
  Write-Host ""
  Read-Host "Press Enter to close"
  exit 1
}
function Done($msg) { Write-Host "   [ok]   $msg" -ForegroundColor Green }
function Skip($msg) { Write-Host "   [skip] $msg" -ForegroundColor DarkGray }
function Warn($msg) { Write-Host "   [!]    $msg" -ForegroundColor Yellow }

# Run a native command (git/gh) without $ErrorActionPreference="Stop"
# turning its stderr chatter into a script-killing exception.
function Run-Native {
  param([string]$Exe, [string[]]$ArgList)
  $old = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $out = & $Exe @ArgList 2>&1
  $script:NativeExit = $LASTEXITCODE
  $ErrorActionPreference = $old
  return (($out | ForEach-Object { "$_" }) -join "`n").Trim()
}

# --- resolve the project root (same pattern as Remote-Start) --------
if ($ManualProjectPath -ne "") {
  $ProjectPath = $ManualProjectPath
} else {
  $ProjectPath = $PSScriptRoot
  for ($i = 0; $i -lt $LevelsUp; $i++) {
    $parent = Split-Path $ProjectPath -Parent
    if ([string]::IsNullOrEmpty($parent)) { Fail "Auto-detect walked above the drive root. Check LevelsUp." }
    $ProjectPath = $parent
  }
}
if (-not (Test-Path $ProjectPath)) { Fail "Project folder not found: $ProjectPath" }
$driveRoot = [System.IO.Path]::GetPathRoot($ProjectPath)
if ($ProjectPath.TrimEnd('\') -eq $driveRoot.TrimEnd('\')) {
  Fail "Auto-detected path is a drive root ($ProjectPath). Put the PROJECT KIT folder INSIDE your project's root folder (or set LevelsUp = 0 if its files sit directly in the root)."
}

$ProjectName = Split-Path $ProjectPath -Leaf
$KitDir      = $PSScriptRoot
$TemplateDir = Join-Path $KitDir "templates"
$Stamp       = Get-Date -Format "yyyy-MM-dd"
if (-not (Test-Path $TemplateDir)) { Fail "templates\ folder not found next to this script. Keep the PROJECT KIT folder intact." }

function Expand-Template([string]$text) {
  return $text.Replace('{{PROJECT_NAME}}', $ProjectName).Replace('{{DATE}}', $Stamp)
}
function Write-Text([string]$path, [string]$text) {
  [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

Write-Host ""
Write-Host "  =====================================================" -ForegroundColor DarkYellow
Write-Host "   CLAUDE CODE PROJECT KIT - Bootstrap" -ForegroundColor Yellow
Write-Host "  =====================================================" -ForegroundColor DarkYellow
Write-Host "   Project : $ProjectPath"
Write-Host "   Name    : $ProjectName"
Write-Host ""

# ====================================================================
# 1) PROJECT KNOWLEDGE skeleton — create only what's missing
# ====================================================================
Write-Host "  -- PROJECT KNOWLEDGE --------------------------------"
$pkSrc = Join-Path $TemplateDir "PROJECT KNOWLEDGE"
$pkDst = Join-Path $ProjectPath "PROJECT KNOWLEDGE"
if (-not (Test-Path $pkDst)) {
  New-Item -ItemType Directory -Path $pkDst | Out-Null
  Done "Created PROJECT KNOWLEDGE\"
} else {
  Skip "PROJECT KNOWLEDGE\ already exists"
}
Get-ChildItem $pkSrc -File | Sort-Object Name | ForEach-Object {
  $dst = Join-Path $pkDst $_.Name
  if (Test-Path $dst) {
    Skip "$($_.Name) exists - left untouched"
  } else {
    Write-Text $dst (Expand-Template (Get-Content $_.FullName -Raw))
    Done "Created $($_.Name)"
  }
}

# ====================================================================
# 2) CLAUDE.md — create, or update/append the managed block
# ====================================================================
Write-Host "  -- CLAUDE.md ----------------------------------------"
$tplPath   = Join-Path $TemplateDir "CLAUDE.md"
if (-not (Test-Path $tplPath)) { Fail "templates\CLAUDE.md is missing from the kit." }
$tpl       = Expand-Template (Get-Content $tplPath -Raw)
$beginMark = '<!-- BEGIN PROJECT-KIT DIRECTIVES'
$endMark   = '<!-- END PROJECT-KIT DIRECTIVES -->'
$bi = $tpl.IndexOf($beginMark); $ei = $tpl.IndexOf($endMark)
if ($bi -lt 0 -or $ei -lt 0) { Fail "templates\CLAUDE.md is missing its BEGIN/END markers." }
$block = $tpl.Substring($bi, ($ei - $bi) + $endMark.Length)

$claudePath = Join-Path $ProjectPath "CLAUDE.md"
if (-not (Test-Path $claudePath)) {
  Write-Text $claudePath $tpl
  Done "Created CLAUDE.md with standing directives"
} else {
  $cur = Get-Content $claudePath -Raw
  $cbi = $cur.IndexOf($beginMark); $cei = $cur.IndexOf($endMark)
  if ($cbi -ge 0 -and $cei -gt $cbi) {
    $new = $cur.Substring(0, $cbi) + $block + $cur.Substring($cei + $endMark.Length)
    if ($new -ne $cur) {
      Copy-Item $claudePath "$claudePath.bak" -Force
      Write-Text $claudePath $new
      Done "Updated managed directives block (backup: CLAUDE.md.bak)"
    } else {
      Skip "Managed directives block already up to date"
    }
  } else {
    Copy-Item $claudePath "$claudePath.bak" -Force
    Write-Text $claudePath ($cur.TrimEnd() + "`r`n`r`n" + $block + "`r`n")
    Done "Appended managed directives block to your existing CLAUDE.md (backup: CLAUDE.md.bak)"
  }
}

# ====================================================================
# 3) REMOTE START launcher — copy if missing
# ====================================================================
Write-Host "  -- REMOTE START launcher ----------------------------"
$rsSrc = Join-Path $KitDir "REMOTE START"
$rsDst = Join-Path $ProjectPath "REMOTE START"
if (Test-Path $rsSrc) {
  if (-not (Test-Path $rsDst)) { New-Item -ItemType Directory -Path $rsDst | Out-Null }
  Get-ChildItem $rsSrc -File | ForEach-Object {
    $dst = Join-Path $rsDst $_.Name
    if (Test-Path $dst) { Skip "$($_.Name) exists - left untouched" }
    else { Copy-Item $_.FullName $dst; Done "Installed REMOTE START\$($_.Name)" }
  }
} else {
  Warn "Kit's REMOTE START\ folder not found - launcher skipped"
}

# ====================================================================
# 4) Git init + .gitignore
# ====================================================================
Write-Host "  -- Git ----------------------------------------------"
$haveGit = [bool](Get-Command git -ErrorAction SilentlyContinue)
$originUrl = $null
if (-not $haveGit) {
  Warn "git not found on PATH - all Git/GitHub steps skipped."
  Warn "Install Git for Windows (winget install Git.Git), then re-run this bootstrap."
} else {
  Set-Location $ProjectPath
  if (-not (Test-Path (Join-Path $ProjectPath ".git"))) {
    Run-Native "git" @("init") | Out-Null
    # Set default branch name without requiring git >= 2.28's init -b:
    Run-Native "git" @("symbolic-ref", "HEAD", "refs/heads/$DefaultBranch") | Out-Null
    Done "Initialized git repository (branch: $DefaultBranch)"
  } else {
    Skip "Git repository already initialized"
  }

  $gi = Join-Path $ProjectPath ".gitignore"
  if (-not (Test-Path $gi)) {
    $giBody = @"
# --- Claude Code Project Kit starter .gitignore (extend per stack) ---
# Secrets - never commit these
.env
.env.*
*.pem
*.key

# OS noise
Thumbs.db
desktop.ini
.DS_Store

# Editor / tool noise
.vscode/
.idea/
*.bak
*.tmp

# Common build/dependency output (delete lines that don't apply)
node_modules/
dist/
build/
__pycache__/
*.pyc
bin/
obj/
"@
    Write-Text $gi $giBody
    Done "Created starter .gitignore"
  } else {
    Skip ".gitignore already exists"
  }

  # ==================================================================
  # 5) Initial commit (before remote creation - works on every gh version)
  # ==================================================================
  Write-Host "  -- Initial commit -----------------------------------"
  $dirty = Run-Native "git" @("status", "--porcelain")
  if ($dirty) {
    Run-Native "git" @("add", "-A") | Out-Null
    $out = Run-Native "git" @("commit", "-m", "chore: bootstrap with Claude Code Project Kit")
    if ($script:NativeExit -eq 0) { Done "Committed bootstrap files" }
    else {
      Warn "Commit failed:"
      Write-Host "      $out" -ForegroundColor DarkGray
      if ($out -match "user.name|user.email|identity") {
        Warn "Set your git identity once, then re-run this bootstrap:"
        Write-Host '      git config --global user.name  "Your Name"' -ForegroundColor DarkGray
        Write-Host '      git config --global user.email "you@example.com"' -ForegroundColor DarkGray
      }
    }
  } else {
    Skip "Nothing new to commit"
  }

  # ==================================================================
  # 6) GitHub remote - gh CLI (preferred) or manual URL
  # ==================================================================
  Write-Host "  -- GitHub remote ------------------------------------"
  $existing = Run-Native "git" @("remote", "get-url", "origin")
  if ($script:NativeExit -eq 0 -and $existing) {
    $originUrl = $existing
    Skip "Remote 'origin' already set: $originUrl"
  } else {
    $ghAuthed = $false
    if (Get-Command gh -ErrorAction SilentlyContinue) {
      Run-Native "gh" @("auth", "status") | Out-Null
      if ($script:NativeExit -eq 0) { $ghAuthed = $true }
    }

    if ($ghAuthed) {
      # Suggest a sanitized repo name from the folder, but ALWAYS prompt.
      $suggest = ($ProjectName.ToLower() -replace '[^a-z0-9._-]', '-') -replace '-{2,}', '-'
      $suggest = $suggest.Trim('-')
      if ([string]::IsNullOrWhiteSpace($suggest)) { $suggest = "my-project" }

      for ($try = 1; $try -le 3; $try++) {
        $name = Read-Host "   New PRIVATE repo name on your GitHub profile [Enter = $suggest, type 'skip' to skip]"
        if ([string]::IsNullOrWhiteSpace($name)) { $name = $suggest }
        if ($name -eq "skip") { Warn "Skipped creating a remote - commits will stay local."; break }

        $out = Run-Native "gh" @("repo", "create", $name, "--private", "--source", ".", "--remote", "origin")
        if ($script:NativeExit -eq 0) {
          $originUrl = Run-Native "git" @("remote", "get-url", "origin")
          Done "Created private GitHub repo and set origin: $originUrl"
          break
        } else {
          Warn "gh repo create failed (attempt $try of 3):"
          Write-Host "      $out" -ForegroundColor DarkGray
          if ($try -eq 3) { Warn "Giving up on gh - re-run this bootstrap later or add a remote manually." }
        }
      }
    } else {
      Warn "GitHub CLI not installed or not logged in."
      Warn "(One-time fix: see 'gh auth login' steps in PROJECT KIT\README.md)"
      $url = Read-Host "   Paste an existing GitHub repo URL to use as origin [Enter = skip]"
      if (-not [string]::IsNullOrWhiteSpace($url)) {
        Run-Native "git" @("remote", "add", "origin", $url) | Out-Null
        if ($script:NativeExit -eq 0) { $originUrl = $url; Done "Set origin: $url" }
        else { Warn "Could not add remote - check the URL and re-run." }
      } else {
        Skip "No remote configured - commits will stay local until one is added."
      }
    }
  }

  # ==================================================================
  # 7) Record the repo URL in the handoff doc (+ tiny docs commit)
  # ==================================================================
  $handoff = Join-Path $pkDst "04-HANDOFF.md"
  if ($originUrl -and (Test-Path $handoff)) {
    $h = Get-Content $handoff -Raw
    if ($h -match '\*\*Repository:\*\*') {
      $h2 = $h -replace '\*\*Repository:\*\*[^\r\n]*', "**Repository:** $originUrl"
    } else {
      $h2 = "**Repository:** $originUrl`r`n`r`n" + $h
    }
    if ($h2 -ne $h) {
      Write-Text $handoff $h2
      Done "Recorded repo URL in 04-HANDOFF.md"
      Run-Native "git" @("add", "-A") | Out-Null
      Run-Native "git" @("commit", "-m", "docs: record repository URL in handoff") | Out-Null
    } else {
      Skip "Repo URL already recorded in 04-HANDOFF.md"
    }
  }

  # ==================================================================
  # 8) Push
  # ==================================================================
  if ($originUrl) {
    Write-Host "  -- Push ---------------------------------------------"
    $out = Run-Native "git" @("push", "-u", "origin", "HEAD")
    if ($script:NativeExit -eq 0) { Done "Pushed to origin" }
    else {
      Warn "Push failed - run 'git push -u origin $DefaultBranch' manually once connectivity/auth is sorted:"
      Write-Host "      $out" -ForegroundColor DarkGray
    }
  }
}

# ====================================================================
# Summary
# ====================================================================
Write-Host ""
Write-Host "  =====================================================" -ForegroundColor DarkYellow
Write-Host "   Bootstrap complete." -ForegroundColor Yellow
Write-Host "  =====================================================" -ForegroundColor DarkYellow
Write-Host "   Next:"
Write-Host "    1. Open PROJECT KNOWLEDGE\01-VISION-AND-DESIGN.md and fill in"
Write-Host "       the one-liner + goals (or have Claude interview you for it)."
Write-Host "    2. Seed PROJECT KNOWLEDGE\03-PUNCH-LIST.md with first work items."
Write-Host "    3. Start working: double-click REMOTE START\Remote-Start.bat"
Write-Host "       (or run 'claude' in the project folder)."
Write-Host ""
Write-Host "   Re-running this bootstrap any time is safe: it only adds"
Write-Host "   missing pieces and refreshes the CLAUDE.md managed block."
Write-Host ""
Read-Host "Press Enter to close"
