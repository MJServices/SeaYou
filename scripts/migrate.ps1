Param(
  [string]$LogDir = "docs/logs",
  [int]$MaxRetries = 3
)

function Write-Log {
  Param([string]$Message)
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $line = "[$ts] $Message"
  Write-Host $line
  Add-Content -Path $LogFile -Value $line
}

if (!(Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDir "migration_$stamp.log"

Write-Log "Starting migration run"

$cmd = "npx supabase db push"
$retries = 0
do {
  Write-Log "Attempt $($retries+1): pushing migrations"
  $proc = Start-Process powershell -ArgumentList "-NoProfile","-Command","echo Y | $cmd" -RedirectStandardOutput "$LogDir\push_$stamp.out" -RedirectStandardError "$LogDir\push_$stamp.err" -PassThru -Wait
  $exit = $proc.ExitCode
  $out = Get-Content "$LogDir\push_$stamp.out" -Raw
  $err = Get-Content "$LogDir\push_$stamp.err" -Raw
  Add-Content -Path $LogFile -Value "STDOUT:`n$out"
  Add-Content -Path $LogFile -Value "STDERR:`n$err"

  if ($exit -eq 0) {
    Write-Log "Migration push succeeded"
    break
  } else {
    Write-Log "Migration push failed with exit code $exit"
    if ($err -match 'relation .* does not exist') {
      Write-Log "Detected missing relation; ensure migration order creates base tables before alters"
    }
    if ($err -match 'syntax error at or near "NOT"') {
      Write-Log "Detected unsupported IF NOT EXISTS in CREATE POLICY; using DROP POLICY IF EXISTS + CREATE POLICY"
    }
    if ($err -match 'failed to connect' -or $err -match 'pooler' -or $err -match 'SASL auth') {
      Write-Log "Detected connection/auth issue. Retrying..."
    }
    $retries++
    Start-Sleep -Seconds 3
  }
} while ($retries -lt $MaxRetries)

if ($retries -ge $MaxRetries -and $exit -ne 0) {
  Write-Log "Migration push did not succeed after $MaxRetries attempts. Manual intervention required."
  Write-Log "Suggested steps:"
  Write-Log "1) Update CLI: winget install Supabase.SupabaseCLI or scoop install supabase"
  Write-Log "2) Login: supabase login (paste access token)"
  Write-Log "3) Link: supabase link --project-ref nenugkyvcewatuddrwvf"
  Write-Log "4) Run: supabase db push"
}

Write-Log "Log saved to $LogFile"
