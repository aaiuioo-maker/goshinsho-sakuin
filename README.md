# 御神書索引

岡田茂吉著『御神書』全六巻の目次検索・解説閲覧・読み上げアプリ。

`index.html` 1ファイルで動作します（GitHub Pages で公開）。

## 読み上げ音声

解説付きの項目は、Azure Speech の Nanami（ja-JP-NanamiNeural）で事前に作った MP3（`audio/`）を再生します。
音声がない項目は、端末の音声合成で読み上げます。

### 解説を追加・修正したとき

1. `index.html` のデータを更新する
2. 読み上げ用テキストを取り出す（Microsoft Edge を使用）

   ```
   powershell -ExecutionPolicy Bypass -File tools\extract.ps1
   ```

3. 音声を作る（変わった項目だけ作り直し、使われなくなったファイルは削除される）

   ```
   powershell -ExecutionPolicy Bypass -File tools\tts.ps1 -Voice ja-JP-NanamiNeural
   ```

4. `index.html` と `audio/` をコミットしてプッシュする

Azure のキーは `.azure-speech.json`（`{ "key": "...", "region": "japaneast" }`）に置きます。このファイルは Git に含めません。
