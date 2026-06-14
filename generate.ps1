$ErrorActionPreference='Stop'
$dir = "C:\Users\each2\bluearchive"
$raw = (Get-Content "$dir\students_kr.json" -Raw -Encoding UTF8) -replace '"BirthDay":', '"BirthDayX":'
$json = $raw | ConvertFrom-Json
$all = $json.PSObject.Properties.Name | ForEach-Object { $json.$_ }
$released = $all | Where-Object { $_.IsReleased[0] -eq $true } | Sort-Object DefaultOrder

# ---- 라벨 맵 ----
$SCHOOL = @{
  Abydos='아비도스'; Gehenna='게헨나'; Trinity='트리니티'; Millennium='밀레니엄';
  Hyakkiyako='백귀야행'; Shanhaijing='산해경'; RedWinter='붉은겨울'; Valkyrie='발키리';
  Arius='아리우스'; SRT='SRT'; ETC='기타'; Sakugawa='사쿠가와'; Tokiwadai='토키와다이';
  Highlander='하이랜더'; WildHunt='와일드헌트'
}
$BULLET = @{ Explosion='폭발'; Pierce='관통'; Mystic='신비'; Sonic='진동' }
$ARMOR  = @{ LightArmor='경장갑'; HeavyArmor='중장갑'; Unarmed='특수장갑'; ElasticArmor='탄력장갑'; CompositeArmor='탄력장갑' }
$ROLE   = @{ DamageDealer='딜러'; Tanker='탱커'; Supporter='서포터'; Healer='힐러'; Vehicle='차량' }
$POS    = @{ Front='전열'; Middle='중열'; Back='후열' }
$SQUAD  = @{ Main='스트라이커'; Support='스페셜' }

# 스킬 설명 내 <b:Stat> 토큰 한글화
$STAT = @{
  CriticalChance='치명 발생치'; AttackSpeed='공격 속도'; Attack='공격력'; AttackPower='공격력';
  Defense='방어력'; DefensePower='방어력'; MaxHP='최대 HP'; Heal='회복력'; HealPower='회복력';
  CriticalDamage='치명 대미지'; Accuracy='명중치'; Dodge='회피치'; Stability='안정치';
  Range='사정거리'; AmmoCount='장탄수'; MoveSpeed='이동 속도'; Block='블록';
  Recovery='코스트 회복력'; CriticalResist='치명 저항치'; DamageRatio='대미지'; CCResist='행동 불가 저항'
}

function Clean-Desc($skill){
  if(-not $skill){ return $null }
  $d = [string]$skill.Desc
  if(-not $d){ return $null }
  # <?n> -> Parameters[n-1] 의 (첫 → 마지막) 값
  $params = $skill.Parameters
  $d = [regex]::Replace($d, '<\?(\d+)>', {
    param($m)
    $idx = [int]$m.Groups[1].Value - 1
    if($params -and $idx -lt $params.Count){
      $arr = $params[$idx]
      $first = $arr[0]; $last = $arr[$arr.Count-1]
      if($first -eq $last){ return "$first" } else { return "$first → $last" }
    }
    return $m.Value
  })
  # <b:Stat> -> 한글 스탯명
  $d = [regex]::Replace($d, '<b:([A-Za-z_]+)>', {
    param($m)
    $k = $m.Groups[1].Value
    if($STAT.ContainsKey($k)){ return $STAT[$k] } else { return $k }
  })
  # 남은 태그 제거
  $d = [regex]::Replace($d, '<[^>]*>', '')
  $d = $d -replace '\s+', ' '
  return $d.Trim()
}

function Skill-Obj($skill){
  if(-not $skill){ return $null }
  $o = [ordered]@{ name = [string]$skill.Name; desc = (Clean-Desc $skill) }
  if($skill.Cost){ $o.cost = $skill.Cost[0] }
  return $o
}

# 이름 -> 토큰 집합 (코스튬 포함, '=' 이후 별칭/괄호/구분자 정리)
function Get-Tokens($name){
  $n = ($name -replace "[​﻿]","")
  if($n.Contains('=')){ $n = $n.Substring(0, $n.IndexOf('=')) }
  $n = ($n -replace '[()\*/,]',' ').Trim()
  $toks = @($n -split '\s+' | Where-Object { $_ -ne '' })
  return ,$toks
}

# 프로필 줄에서 스킬 순서 + 권장 레벨 추출
# 스킬번호: 1=기본 2=강화 3=서브 / 레벨문자열 위치: [EX,1,2,3]
function Parse-OrderRec($line){
  $order = $null; $rec = $null
  $map = @{ '1'='기본'; '2'='강화'; '3'='서브'; 'EX'='EX' }
  $m = [regex]::Match($line, '(?:EX|[1-3])(?:\s*[>=]+\s*(?:EX|[1-3]))+')
  if($m.Success){
    $seq = ($m.Value -replace '\s','')
    $parts = @($seq -split '>+' | Where-Object { $_ -ne '' })
    $order = @()
    foreach($p in $parts){
      $subs = @($p -split '=' | Where-Object { $_ -ne '' } | ForEach-Object { $map[$_] })
      $order += ($subs -join '=')
    }
  }
  $lm = [regex]::Matches($line, '[1-9M]{4}')
  if($lm.Count -gt 0){
    $lv = $lm[$lm.Count-1].Value
    $ex = "$($lv[0])"; if($ex -eq 'M'){ $ex = '5' }
    $rec = @{ ex=$ex; normal="$($lv[1])"; passive="$($lv[2])"; sub="$($lv[3])" }
  }
  return @{ order=$order; rec=$rec }
}

# 역할별 권장 스킬작 순서(일반 가이드)
$ORDER = @{
  DamageDealer = @('EX','강화','기본','서브')
  Tanker       = @('강화','EX','기본','서브')
  Healer       = @('EX','기본','강화','서브')
  Supporter    = @('EX','기본','강화','서브')
  Vehicle      = @('EX','강화','기본','서브')
}
$NOTE = @{
  DamageDealer = '주력 화력 — EX와 강화 패시브를 먼저 M까지 올리는 것을 권장'
  Tanker       = '생존이 핵심 — 강화 패시브(생존/방어)를 우선, 그 다음 EX'
  Healer       = '회복량 직결 — EX를 최우선으로, 이후 일반/패시브 M'
  Supporter    = '버프/디버프 효율 — EX 우선, 활용도 따라 일반·패시브 M'
  Vehicle      = 'EX 화력 위주 — 활용 빈도에 따라 나머지 스킬 투자'
}
# 역할별 권장 스킬 레벨 (EX 최대 5 / 일반·패시브·서브 최대 M=10, 우선순위 높은 순으로 M→7→5)
# 키 순서: ex, normal(노말), passive(패시브), sub(서브)
$RECLV = @{
  DamageDealer = @{ ex='5'; normal='7'; passive='M'; sub='5' }
  Tanker       = @{ ex='5'; normal='7'; passive='M'; sub='5' }
  Healer       = @{ ex='5'; normal='M'; passive='7'; sub='5' }
  Supporter    = @{ ex='5'; normal='M'; passive='7'; sub='5' }
  Vehicle      = @{ ex='5'; normal='7'; passive='M'; sub='5' }
}

# 한정/상시 판별 + 모집 팁 (IsLimited[0]: 0·4=상시 / 1·2·3=한정·이벤트·페스 한정)
function Pickup-Info($s){
  $code = [int]$s.IsLimited[0]
  $rar  = [int]$s.StarGrade
  $isLimited = ($code -ne 0 -and $code -ne 4)
  if($isLimited){
    $tip = '한정 모집 학생 — 상시 모집에 없고 복각 주기가 길어요. 필요하면 픽업 기간에 확보를 강력 권장!'
  } elseif($rar -ge 3){
    $tip = '상시 모집 ★3 — 픽업 기간에 효율적으로 노릴 수 있어요. 무돌로도 활용 가능, 여유되면 풀돌(전용무기·성장) 추천.'
  } else {
    $tip = '상시 일반 모집 — 자주 등장해 풀돌(고유성 작)이 쉬운 편. 부담 없이 육성하세요.'
  }
  return @{ limited = $isLimited; tip = $tip }
}

# ===== 팁스.txt 파싱: 추천도(★) + 프로필(순서·레벨) + 사용자 팁(*) =====
$tipPath = "C:\Users\each2\Downloads\팁스.txt"
$TIPENTRIES = @()
if(Test-Path $tipPath){
  $cur = $null; $pendingRating = $null
  foreach($ln in (Get-Content $tipPath -Encoding UTF8)){
    $t = ($ln -replace '[​﻿]','').Trim()
    if($t -eq ''){ continue }
    if($t -match '^[★☆]+$'){
      $pendingRating = ($t -replace '★','♥' -replace '☆','♡')
    } elseif($t -match 'STRIKER|SPECIAL'){
      if($cur){ $TIPENTRIES += $cur }
      $por = Parse-OrderRec $t
      $cur = [pscustomobject]@{
        tokens = (Get-Tokens (($t -split '/')[0]))
        tips   = @()
        order  = $por.order
        rec    = $por.rec
        rating = $pendingRating
      }
      $pendingRating = $null
    } elseif($t.StartsWith('*')){
      if($cur){
        $tip = $t.TrimStart('*').Trim()
        if($tip -ne ''){ $cur.tips += $tip }
      }
    }
  }
  if($cur){ $TIPENTRIES += $cur }
}
"팁 항목 파싱: $($TIPENTRIES.Count)개"

# 학생 이름 토큰이 항목 토큰의 부분집합인 것 중 가장 작은(=정확한) 항목 반환
function Match-Entry($sname){
  $S = Get-Tokens $sname
  $best=$null; $bestSize=[int]::MaxValue
  foreach($e in $TIPENTRIES){
    $T = $e.tokens; $all=$true
    foreach($tok in $S){ if($T -notcontains $tok){ $all=$false; break } }
    if($all -and $T.Count -lt $bestSize){ $best=$e; $bestSize=$T.Count }
  }
  return $best
}

$students = foreach($s in $released){
  $roleRaw = [string]$s.TacticRole
  $pk = Pickup-Info $s
  $m = Match-Entry ([string]$s.Name)
  $custom  = if($m){ ,$m.tips } else { $null }
  $ordVal  = if($m -and $m.order -and $m.order.Count){ $m.order } else { $ORDER[$roleRaw] }
  $recVal  = if($m -and $m.rec){ $m.rec } else { $(if($RECLV.ContainsKey($roleRaw)){ $RECLV[$roleRaw] } else { $RECLV['DamageDealer'] }) }
  $rateVal = if($m){ $m.rating } else { $null }
  [ordered]@{
    id        = $s.Id
    name      = [string]$s.Name
    school    = $(if($SCHOOL.ContainsKey([string]$s.School)){ $SCHOOL[[string]$s.School] } else { [string]$s.School })
    rarity    = $s.StarGrade
    atk       = ([string]$s.BulletType).ToLower()
    atkLabel  = $(if($BULLET.ContainsKey([string]$s.BulletType)){ $BULLET[[string]$s.BulletType] } else { [string]$s.BulletType })
    armor     = $(if($ARMOR.ContainsKey([string]$s.ArmorType)){ $ARMOR[[string]$s.ArmorType] } else { [string]$s.ArmorType })
    role      = $(if($ROLE.ContainsKey($roleRaw)){ $ROLE[$roleRaw] } else { $roleRaw })
    position  = $(if($POS.ContainsKey([string]$s.Position)){ $POS[[string]$s.Position] } else { [string]$s.Position })
    squad     = $(if($SQUAD.ContainsKey([string]$s.SquadType)){ $SQUAD[[string]$s.SquadType] } else { [string]$s.SquadType })
    img       = "https://schaledb.com/images/student/collection/$($s.Id).webp"
    icon      = "https://schaledb.com/images/student/icon/$($s.Id).webp"
    ex        = (Skill-Obj $s.Skills.Ex)
    normal    = (Skill-Obj $s.Skills.Public)
    passive   = (Skill-Obj $s.Skills.Passive)
    sub       = (Skill-Obj $s.Skills.ExtraPassive)
    order     = $ordVal
    note      = $NOTE[$roleRaw]
    rec       = $recVal
    limited   = $pk.limited
    tip       = $pk.tip
    tips      = $custom
    rating    = $rateVal
  }
}

$jsonOut = $students | ConvertTo-Json -Depth 6
$content = "/* 자동 생성 데이터 — SchaleDB(schaledb.com) 한국 서버 기준. 출시 학생 $($students.Count)명. */`r`nconst STUDENTS = $jsonOut;"
$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText("$dir\data.js", $content, $enc)
"생성 완료: data.js ($($students.Count)명)"