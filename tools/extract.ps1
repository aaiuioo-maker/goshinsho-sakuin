# index.html から「解説付き」項目の読み上げ用テキストを取り出し、tools/work/entries.json に保存する。
# アプリと同じ ttsSplit()（読み上げ向けの整形）を使うため、Edge をヘッドレスで動かして実行する。
# 使い方: powershell -ExecutionPolicy Bypass -File tools\extract.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$work = Join-Path $PSScriptRoot 'work'
New-Item -ItemType Directory -Force $work | Out-Null

$html = [System.IO.File]::ReadAllText((Join-Path $root 'index.html'), [System.Text.Encoding]::UTF8)

# アプリ本体のスクリプトのあとに、データを JSON にして画面に書き出すスクリプトを足す
$inject = @'
<script>
(function () {
  const out = [];
  for (const volId in goshinshoData) {
    goshinshoData[volId].chapters.forEach(ch => ch.entries.forEach((e, i) => {
      if (!e.content) return;
      out.push({ ref: volId + "|" + ch.name + "|" + i, title: e.title,
                 chunks: ttsSplit(e.title + "。\n" + e.content) });
    }));
  }
  document.body.innerHTML = "";
  const pre = document.createElement("pre");
  pre.id = "out";
  pre.textContent = JSON.stringify(out);
  document.body.appendChild(pre);
})();
</script>
'@
$html = $html.Replace('</body>', $inject + '</body>')
$page = Join-Path $work 'extract.html'
[System.IO.File]::WriteAllText($page, $html, (New-Object System.Text.UTF8Encoding $false))

$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
          "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw 'Microsoft Edge が見つかりません' }

$url = 'file:///' + ($page -replace '\\', '/')
$profileDir = Join-Path $env:TEMP 'goshinsho-edge-profile'
$dom = & $edge --headless=new --disable-gpu --no-first-run --user-data-dir="$profileDir" --virtual-time-budget=5000 --dump-dom $url 2>$null | Out-String

$m = [regex]::Match($dom, '<pre id="out">([\s\S]*?)</pre>')
if (-not $m.Success) { throw 'データを取り出せませんでした' }
$json = [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value)
[System.IO.File]::WriteAllText((Join-Path $work 'entries.json'), $json, (New-Object System.Text.UTF8Encoding $false))
$list = $json | ConvertFrom-Json
Write-Output ("{0} 項目を取り出しました" -f $list.Count)
