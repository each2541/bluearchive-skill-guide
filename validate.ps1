# pickup.js 검증: 픽업/복각에 적힌 이름이 모두 실제 학생(data.js)과 매칭되는지 확인.
# 매칭 안 되는 이름이 있으면 비정상 종료(exit 1) → CI 실패로 오타를 잡아냄.
$ErrorActionPreference = 'Stop'
$dir = if($PSScriptRoot){ $PSScriptRoot } else { (Get-Location).Path }

# data.js → 학생 이름 집합
$data = Get-Content (Join-Path $dir 'data.js') -Raw -Encoding UTF8
$arr  = ($data.Substring($data.IndexOf('['))).TrimEnd(";`r`n ".ToCharArray()) | ConvertFrom-Json
$names = @{}; $arr | ForEach-Object { $names[[string]$_.name] = $true }

# pickup.js → pickup/rerun 배열 추출
$pk = Get-Content (Join-Path $dir 'pickup.js') -Raw -Encoding UTF8
function Get-List([string]$key,[string]$text){
  $m = [regex]::Match($text, $key + '\s*:\s*\[(.*?)\]', [System.Text.RegularExpressions.RegexOptions]::Singleline)
  if(-not $m.Success){ return @() }
  return @([regex]::Matches($m.Groups[1].Value, '"([^"]*)"') | ForEach-Object { $_.Groups[1].Value })
}

$missing = @()
foreach($key in 'pickup','rerun'){
  foreach($nm in (Get-List $key $pk)){
    if(-not $names.ContainsKey($nm)){ $missing += "$key 항목 '$nm'" }
  }
}

if($missing.Count){
  Write-Host "[FAIL] pickup.js에 data.js와 매칭되지 않는 이름이 있습니다:"
  $missing | ForEach-Object { Write-Host "   - $_" }
  Write-Host "정확한 학생 이름인지(코스튬 표기 포함) 확인하세요."
  exit 1
}
Write-Host "[OK] pickup.js 검증 통과 — 모든 픽업/복각 이름이 실제 학생과 매칭됩니다. (학생 $($arr.Count)명)"
