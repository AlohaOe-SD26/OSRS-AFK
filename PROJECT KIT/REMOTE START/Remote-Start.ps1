# ============================================================
#  Remote-Start.ps1 — portable Claude Code remote launcher
#
#  HOW TO USE: make a folder inside your project's root folder
#  (e.g.  <ProjectRoot>\REMOTE START\ ), put BOTH files in it
#  (Remote-Start.bat + Remote-Start.ps1), then double-click the
#  .bat. No editing required — it auto-detects the project root
#  as the PARENT of the folder it lives in, and uses the project
#  folder's name as the session title on your phone.
#
#  Works in any project: just copy the folder into another
#  project's root.
# ============================================================

# ---- optional knobs (defaults work for the setup above) ----
# How many folders UP from this script is the project root?
#   1 = script lives in a subfolder of the project root (recommended)
#   0 = script sits directly in the project root itself
$LevelsUp = 1
# Set a custom phone-visible session title, or leave "" to use the
# project folder's name automatically:
$TitleOverride = ""
# Hard override: set a full path here to ignore auto-detection entirely:
$ManualProjectPath = ""
# ------------------------------------------------------------

$ErrorActionPreference = "Stop"

function Fail($msg) {
  Write-Host ""
  Write-Host "  ERROR: $msg" -ForegroundColor Red
  Write-Host ""
  Read-Host "Press Enter to close"
  exit 1
}

# --- resolve the project root --------------------------------------
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

# --- sanity checks --------------------------------------------------
if (-not (Test-Path $ProjectPath)) { Fail "Project folder not found: $ProjectPath" }
$root = [System.IO.Path]::GetPathRoot($ProjectPath)
if ($ProjectPath.TrimEnd('\') -eq $root.TrimEnd('\')) {
  Fail "Auto-detected path is a drive root ($ProjectPath) - the launcher folder is probably in the wrong place. Put it in a folder INSIDE your project's root folder (or set LevelsUp = 0 if it sits directly in the root)."
}
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  Fail "The 'claude' command isn't available in PowerShell. Install/repair Claude Code first."
}

$SessionTitle = if ($TitleOverride -ne "") { $TitleOverride } else { Split-Path $ProjectPath -Leaf }
Set-Location $ProjectPath

# --- status banner --------------------------------------------------
$ver = (& claude --version) 2>$null
$cfg = "$env:USERPROFILE\.claude.json"
$alwaysOn = $false
if (Test-Path $cfg) {
  $alwaysOn = (Select-String -Path $cfg -Pattern '"remoteControlAtStartup"\s*:\s*true' -Quiet)
}

Write-Host ""
Write-Host "  =====================================================" -ForegroundColor DarkYellow
Write-Host "   REMOTE START - Claude Code Launcher" -ForegroundColor Yellow
Write-Host "  =====================================================" -ForegroundColor DarkYellow
Write-Host "   Project : $ProjectPath"
Write-Host "   Title   : $SessionTitle"
Write-Host "   Claude  : $ver"
Write-Host "   Remote-by-default config: $(if ($alwaysOn) {'ON'} else {'off (launcher forces remote anyway)'})"
Write-Host ""
Write-Host "   [1] Resume MOST RECENT session here (+ remote)   <- usual choice"
Write-Host "   [2] PICK a past session to resume (+ remote)"
Write-Host "   [3] Start a FRESH session (+ remote)"
Write-Host ""
$choice = Read-Host "  Choose 1, 2, or 3 (Enter = 1)"
if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "1" }

Write-Host ""
Write-Host "  Keep this window OPEN - closing it ends remote access." -ForegroundColor Cyan
Write-Host "  Phone: Claude app -> Code tab -> '$SessionTitle' (green dot)." -ForegroundColor Cyan
Write-Host "  If it doesn't auto-appear, open the session URL printed below" -ForegroundColor Cyan
Write-Host "  once in your phone's browser (known listing bug)." -ForegroundColor Cyan
Write-Host ""

switch ($choice) {
  "1" { & claude --continue --remote-control $SessionTitle }
  "2" { & claude --resume   --remote-control $SessionTitle }
  "3" { & claude            --remote-control $SessionTitle }
  default { & claude --continue --remote-control $SessionTitle }
}

# If the combined flags ever misbehave on a given version, fall back to:
#   choose your session normally, then type /remote-control inside it.
Write-Host ""
Read-Host "Session ended. Press Enter to close"
