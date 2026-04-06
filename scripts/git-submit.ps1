param(
  [string]$Message = "Update moemail configuration",
  [string]$RemoteName = "origin",
  [string]$RemoteUrl = "https://github.com/blenceming/moemail.git",
  [string]$Branch = "",
  [string[]]$Paths = @("."),
  [switch]$SetRemote,
  [switch]$ForcePush,
  [switch]$NoPush,
  [switch]$Yes
)

$ErrorActionPreference = "Stop"

function Invoke-Git {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GitArgs
  )

  & git @GitArgs
  if ($LASTEXITCODE -ne 0) {
    throw "git $($GitArgs -join ' ') failed with exit code $LASTEXITCODE"
  }
}

function Get-GitOutput {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GitArgs
  )

  $output = & git @GitArgs
  if ($LASTEXITCODE -ne 0) {
    throw "git $($GitArgs -join ' ') failed with exit code $LASTEXITCODE"
  }

  return $output
}

function Confirm-Continue {
  param([string]$Prompt)

  if ($Yes) {
    return $true
  }

  $answer = Read-Host "$Prompt [y/N]"
  return $answer -match "^(y|yes)$"
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $repoRoot

try {
  $gitDir = Join-Path $repoRoot ".git"

  if ($Paths.Count -eq 1 -and $Paths[0].Contains(",")) {
    $Paths = $Paths[0].Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  }

  if (-not (Test-Path $gitDir)) {
    if (-not $Branch) {
      $Branch = "master"
    }

    Write-Host "No .git directory found. Initializing repository..."
    Invoke-Git init
    Invoke-Git checkout -B $Branch
  }

  Invoke-Git rev-parse --is-inside-work-tree | Out-Null

  if (-not $Branch) {
    $Branch = (Get-GitOutput branch --show-current).Trim()
  }

  if (-not $Branch) {
    throw "Current HEAD is detached. Pass -Branch explicitly before pushing."
  }

  Write-Host "Repository: $repoRoot"
  Write-Host "Branch:     $Branch"
  Write-Host "Remote:     $RemoteName -> $RemoteUrl"
  Write-Host ""

  $existingRemoteUrl = $null
  $remoteNames = @()
  try {
    $remoteNames = @(Get-GitOutput remote)
  } catch {
    $remoteNames = @()
  }

  if ($remoteNames -contains $RemoteName) {
    $existingRemoteUrl = (Get-GitOutput remote get-url $RemoteName).Trim()
  }

  if (-not $existingRemoteUrl) {
    Write-Host "Remote '$RemoteName' does not exist. Adding it..."
    Invoke-Git remote add $RemoteName $RemoteUrl
  } elseif ($existingRemoteUrl -ne $RemoteUrl) {
    Write-Host "Remote '$RemoteName' currently points to:"
    Write-Host "  $existingRemoteUrl"
    Write-Host "Expected:"
    Write-Host "  $RemoteUrl"

    if ($SetRemote -or (Confirm-Continue "Update '$RemoteName' to the expected URL?")) {
      Invoke-Git remote set-url $RemoteName $RemoteUrl
    } else {
      throw "Remote URL was not updated. Re-run with -SetRemote or pass another -RemoteName."
    }
  }

  $status = Get-GitOutput status --short
  if ($status) {
    Write-Host "Pending changes:"
    $status | ForEach-Object { Write-Host $_ }
    Write-Host ""

    if (-not (Confirm-Continue "Stage paths, create commit, and push to '$RemoteName/$Branch'?")) {
      Write-Host "Canceled."
      exit 0
    }

    Invoke-Git add -- $Paths

    & git diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
      Write-Host "No staged changes to commit."
    } else {
      Invoke-Git commit -m $Message
    }
  } else {
    Write-Host "No local changes to commit."
  }

  if ($NoPush) {
    Write-Host "Skipped push because -NoPush was provided."
    exit 0
  }

  & git rev-parse --verify HEAD *> $null
  if ($LASTEXITCODE -ne 0) {
    throw "There is no local commit to push yet."
  }

  if ($ForcePush) {
    Invoke-Git push -u $RemoteName $Branch --force
  } else {
    Invoke-Git push -u $RemoteName $Branch
  }

  Write-Host "Done."
} finally {
  Pop-Location
}
