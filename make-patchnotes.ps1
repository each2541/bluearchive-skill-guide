# git 커밋 로그 → patchnotes.html 자동 생성 (블루아카이브 테마).
# patchnotes.html은 .gitignore 처리되어 저장소에는 올라가지 않는 로컬 보기용 파일.
$ErrorActionPreference = 'Stop'
$dir = if($PSScriptRoot){ $PSScriptRoot } else { (Get-Location).Path }

# 커밋 로그: 날짜<US>제목  (US = 0x1f 구분자)
$raw = & git -C $dir log --date=format:'%Y-%m-%d' --pretty=format:"%ad`u{001f}%s"
$commits = foreach($line in $raw){
  if(-not $line){ continue }
  $p = $line -split "`u{001f}", 2
  [pscustomobject]@{ date = $p[0]; msg = $p[1] }
}

function HtmlEnc([string]$s){ $s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' }
function Categorize([string]$m){
  if($m -match '(?i)fix|remove duplicate|버그|수정|dedup'){ return @('수정','fix') }
  if($m -match '(?i)separate|refactor|improve|개선|automation|auto-'){ return @('개선','improve') }
  if($m -match '(?i)add|new|추가|create|initial'){ return @('추가','add') }
  if($m -match '(?i)chore|data|refresh|갱신'){ return @('데이터','data') }
  return @('변경','change')
}

# 날짜별 그룹 (git log는 최신순)
$groups = $commits | Group-Object date
$body = ""
foreach($g in $groups){
  $items = ""
  foreach($c in $g.Group){
    $cat = Categorize $c.msg
    $items += "      <li class=`"item`"><span class=`"badge $($cat[1])`">$($cat[0])</span><div class=`"desc`">$(HtmlEnc $c.msg)</div></li>`n"
  }
  $body += @"
  <div class="rel">
    <div class="rel-head"><span class="ver">$($g.Name)</span><span class="cnt">$($g.Group.Count)건</span></div>
    <ul class="items">
$items    </ul>
  </div>

"@
}

$today = (Get-Date).ToString('yyyy-MM-dd')
$total = @($commits).Count

$html = @"
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>블루아카이브 스킬 정리 — 패치노트</title>
<style>
  @font-face{font-family:'Gyeonggi'; src:url('fonts/Title_Medium.woff') format('woff'); font-weight:400; font-display:swap}
  @font-face{font-family:'Gyeonggi'; src:url('fonts/Title_Bold.woff') format('woff'); font-weight:700; font-display:swap}
  :root{--panel:#16233a;--panel2:#1d2f4d;--line:#28406a;--txt:#e8eef7;--sub:#9fb3d1;--accent:#4ea6ff;--accent2:#7ed0ff;
    --add:#41d18b;--improve:#4ea6ff;--fix:#ff7a8a;--data:#b98bff;--change:#9fb3d1}
  *{box-sizing:border-box}
  body{margin:0;font-family:'Gyeonggi',"Malgun Gothic",system-ui,sans-serif;color:var(--txt);min-height:100vh;line-height:1.6;background:#0b1320}
  body::before{content:"";position:fixed;inset:0;z-index:-2;background:url('https://schaledb.com/images/background/BG_Abydos_Collection.jpg') center/cover no-repeat fixed;opacity:.16}
  body::after{content:"";position:fixed;inset:0;z-index:-1;background:linear-gradient(160deg,rgba(11,19,32,.86),rgba(14,23,38,.92) 45%,rgba(16,29,51,.9))}
  header{text-align:center;padding:38px 16px 20px;border-bottom:1px solid var(--line);background:radial-gradient(80% 120% at 50% 0%,rgba(78,166,255,.18),transparent 70%)}
  header h1{margin:0;font-size:clamp(22px,4.5vw,32px);font-weight:700;letter-spacing:-.5px}
  header h1 .dot{color:var(--accent)}
  header p{margin:8px 0 0;color:var(--sub);font-size:13px}
  .wrap{max-width:820px;margin:0 auto;padding:24px 16px 80px}
  .rel{position:relative;padding:0 0 6px 24px;margin-bottom:22px;border-left:2px solid var(--line)}
  .rel::before{content:"";position:absolute;left:-8px;top:5px;width:13px;height:13px;border-radius:50%;background:var(--accent);box-shadow:0 0 0 4px rgba(78,166,255,.18)}
  .rel:first-child::before{background:#ffc85a;box-shadow:0 0 0 4px rgba(255,200,90,.22)}
  .rel-head{display:flex;align-items:baseline;gap:10px;margin-bottom:11px}
  .ver{font-size:18px;font-weight:800}
  .cnt{font-size:12px;color:var(--sub)}
  ul.items{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:8px}
  li.item{display:flex;gap:10px;align-items:flex-start;background:var(--panel);border:1px solid var(--line);border-radius:11px;padding:10px 12px;box-shadow:0 4px 12px rgba(0,0,0,.18)}
  .badge{flex:none;font-size:11px;font-weight:800;padding:3px 9px;border-radius:7px;margin-top:1px;min-width:42px;text-align:center;color:#06131f}
  .badge.add{background:var(--add)}.badge.improve{background:var(--improve)}.badge.fix{background:var(--fix)}.badge.data{background:var(--data)}.badge.change{background:var(--change)}
  .desc{font-size:13.5px}
  footer{text-align:center;color:#5d738f;font-size:12px;padding:10px 16px 50px}
</style>
</head>
<body>
<header>
  <h1>블루아카이브 스킬 정리 <span class="dot">·</span> 패치노트</h1>
  <p>git 커밋 기록으로 자동 생성 · 최신순</p>
</header>
<div class="wrap">
$body</div>
<footer>총 $total개 변경 · 생성 $today · git 로그 기반 자동 생성(make-patchnotes.ps1)</footer>
</body>
</html>
"@

$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $dir 'patchnotes.html'), $html, $enc)
Write-Host "patchnotes.html 생성 완료 — 커밋 $total건"
