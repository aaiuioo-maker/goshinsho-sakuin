# Azure Speech で「解説付き」項目の音声（MP3）を作る。
#
# 準備: tools\extract.ps1 を先に実行して tools\work\entries.json を作っておく。
#       キーは .azure-speech.json（Git には上げない）に { "key": "...", "region": "japaneast" } で保存。
#
# 使い方:
#   試聴用に1項目だけ作る : powershell -ExecutionPolicy Bypass -File tools\tts.ps1 -Sample "幸福の秘訣" -Voice ja-JP-NanamiNeural
#   全項目を作る          : powershell -ExecutionPolicy Bypass -File tools\tts.ps1 -Voice ja-JP-NanamiNeural
#
# 全項目モードでは、音声ファイル名を「声＋読み上げ文」のハッシュにしている。
# 解説を直すと文が変わってファイル名も変わるため、変わった項目だけが作り直され、変わっていない項目は再利用される。
param(
  [string]$Voice = 'ja-JP-NanamiNeural',
  [string]$Sample = ''
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$work = Join-Path $PSScriptRoot 'work'
$utf8 = New-Object System.Text.UTF8Encoding $false

$cfg = Get-Content (Join-Path $root '.azure-speech.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$entries = [IO.File]::ReadAllText((Join-Path $work 'entries.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$endpoint = "https://$($cfg.region).tts.speech.microsoft.com/cognitiveservices/v1"
$headers = @{
  'Ocp-Apim-Subscription-Key' = $cfg.key
  'X-Microsoft-OutputFormat'  = 'audio-24khz-48kbitrate-mono-mp3'
  'User-Agent'                = 'goshinsho-sakuin'
}

function Get-Text($e) { ($e.chunks -join '') }

function Get-Hash([string]$s) {
  $sha = [Security.Cryptography.SHA1]::Create()
  (($sha.ComputeHash($utf8.GetBytes($s)) | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 16)
}

function Invoke-Tts([string]$text, [string]$outFile) {
  $escaped = [Security.SecurityElement]::Escape($text)
  $ssml = "<speak version='1.0' xml:lang='ja-JP'><voice name='$Voice'>$escaped</voice></speak>"
  for ($try = 1; $try -le 6; $try++) {
    try {
      Invoke-WebRequest -Uri $endpoint -Method Post -Headers $headers -ContentType 'application/ssml+xml; charset=utf-8' `
        -Body $utf8.GetBytes($ssml) -OutFile $outFile -UseBasicParsing | Out-Null
      if ((Get-Item $outFile).Length -gt 1000) { return }
      throw '音声データが空でした'
    } catch {
      $code = $null
      if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
      if ($code -eq 401) { throw 'キーが正しくありません（401）。.azure-speech.json を確認してください。' }
      if ($try -eq 6) { throw "音声の作成に失敗しました: $($_.Exception.Message)" }
      # 無料プランは1秒あたりの回数に制限があるので、待ってからやり直す
      Start-Sleep -Seconds ([Math]::Min(60, 5 * $try))
    }
  }
}

if ($Sample) {
  $e = $entries | Where-Object { $_.title -eq $Sample } | Select-Object -First 1
  if (-not $e) { throw "「$Sample」が見つかりません" }
  $out = Join-Path $work ("sample-" + $Voice + ".mp3")
  Invoke-Tts (Get-Text $e) $out
  Write-Output "試聴用: $out"
  return
}

$audioDir = Join-Path $root 'audio'
New-Item -ItemType Directory -Force $audioDir | Out-Null
$manifest = [ordered]@{}
$made = 0; $reused = 0; $chars = 0
$i = 0
foreach ($e in $entries) {
  $i++
  $text = Get-Text $e
  $name = (Get-Hash ($Voice + '|' + $text)) + '.mp3'
  $file = Join-Path $audioDir $name
  if (Test-Path $file) {
    $reused++
  } else {
    Write-Output ("[{0}/{1}] {2}" -f $i, $entries.Count, $e.title)
    Invoke-Tts $text $file
    $made++; $chars += $text.Length
    Start-Sleep -Milliseconds 300
  }
  $manifest[$e.ref] = 'audio/' + $name
}

# 使われなくなった古い音声ファイルを片付ける
$used = @($manifest.Values | ForEach-Object { Split-Path $_ -Leaf })
Get-ChildItem $audioDir -Filter *.mp3 | Where-Object { $used -notcontains $_.Name } | Remove-Item

$out = [ordered]@{ voice = $Voice; files = $manifest }
[IO.File]::WriteAllText((Join-Path $audioDir 'manifest.json'), ($out | ConvertTo-Json -Depth 4), $utf8)
Write-Output ("完了: 新規 {0} 件（{1} 文字）、再利用 {2} 件" -f $made, $chars, $reused)
