# 御神書索引のアイコン（PNG）を生成する
# 使い方: powershell -ExecutionPolicy Bypass -File tools\make-icon.ps1
Add-Type -AssemblyName System.Drawing

function New-Icon([int]$size, [string]$path, [bool]$mascot = $true) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.TextRenderingHint = 'AntiAliasGridFit'
  $s = $size / 512.0

  # 背景：墨色のグラデーション（上が少し明るい）
  $rect = New-Object System.Drawing.Rectangle 0, 0, $size, $size
  $bg = [System.Drawing.Drawing2D.LinearGradientBrush]::new($rect, [System.Drawing.Color]::FromArgb(0x3a,0x2e,0x22), [System.Drawing.Color]::FromArgb(0x14,0x11,0x0d), [single]90)
  $g.FillRectangle($bg, $rect)

  $gold   = [System.Drawing.Color]::FromArgb(0xe6,0xc8,0x7a)
  $goldDk = [System.Drawing.Color]::FromArgb(0x8a,0x73,0x40)

  # 二重の金枠
  $p1 = New-Object System.Drawing.Pen $gold, (6 * $s)
  $p2 = New-Object System.Drawing.Pen $goldDk, (2 * $s)
  $g.DrawRectangle($p1, 40*$s, 40*$s, 432*$s, 432*$s)
  $g.DrawRectangle($p2, 58*$s, 58*$s, 396*$s, 396*$s)

  $brush = New-Object System.Drawing.SolidBrush $gold

  # 文字を輪郭（パス）に変換し、実際の字形の外接枠で中央合わせして描く。
  # DrawString は文字枠で字形を切り取ってしまうため使わない。
  function Draw-Centered([string]$text, [string]$family, $style, [double]$em, [double]$cx, [double]$cy) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddString($text, (New-Object System.Drawing.FontFamily $family), [int]$style, [single]$em, [System.Drawing.PointF]::new(0, 0), [System.Drawing.StringFormat]::GenericTypographic)
    $b = $path.GetBounds()
    $m = New-Object System.Drawing.Drawing2D.Matrix
    $m.Translate([single]($cx - $b.X - $b.Width / 2), [single]($cy - $b.Y - $b.Height / 2))
    $path.Transform($m)
    $g.FillPath($brush, $path)
    $path.Dispose()
  }

  $center = $size / 2
  # 上部の紋（❀）
  Draw-Centered ([string][char]0x2740) 'Segoe UI Symbol' ([System.Drawing.FontStyle]::Regular) (52*$s) $center (108*$s)
  # 中央の大きな「御」
  Draw-Centered ([string][char]0x5FA1) 'Yu Mincho' ([System.Drawing.FontStyle]::Bold) (215*$s) $center (250*$s)
  # 下部の「神書索引」
  $sub = -join ([char[]](0x795E,0x66F8,0x7D22,0x5F15))
  Draw-Centered $sub 'Yu Mincho' ([System.Drawing.FontStyle]::Bold) (46*$s) $center (410*$s)

  # 左上に Claude Code のキャラクター（サイトのヘッダーと同じ 12×8 ドット）
  # 32px のタブ用アイコンでは潰れて見えないので描かない
  if ($mascot) {
    $g.SmoothingMode = 'None'
    $dot = [Math]::Max(1, [Math]::Round(6 * $s))   # 1ドットの大きさ（512px では 6px）
    $ox = [Math]::Round(76 * $s); $oy = [Math]::Round(76 * $s)
    $orange = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(0xd9,0x77,0x57))
    $dark   = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(0x1a,0x16,0x12))
    # [x, y, 幅, 高さ]（ドット単位）
    $parts = @(@(2,0,8,6), @(0,2,2,2), @(10,2,2,2), @(2,6,1,2), @(4,6,1,2), @(7,6,1,2), @(9,6,1,2))
    foreach ($p in $parts) { $g.FillRectangle($orange, $ox + $p[0]*$dot, $oy + $p[1]*$dot, $p[2]*$dot, $p[3]*$dot) }
    foreach ($e in @(@(3,1), @(8,1))) { $g.FillRectangle($dark, $ox + $e[0]*$dot, $oy + $e[1]*$dot, $dot, $dot) }
  }

  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
}

$root = Split-Path $PSScriptRoot -Parent
New-Icon 512 (Join-Path $root 'icon-512.png')
New-Icon 180 (Join-Path $root 'apple-touch-icon.png')
New-Icon 32  (Join-Path $root 'favicon-32.png') $false

