# 御神書索引

岡田茂吉著『御神書』全六巻の目次検索・解説閲覧・読み上げアプリ。

`index.html` 1ファイルで動作します（GitHub Pages で公開）。

## 読み上げ音声

解説付きの項目は、VOICEVOX で事前に作った MP3（`audio/`）を再生します。
一文ごとに 四国めたん → 春日部つむぎ → 雨晴はう → 小夜/SAYO の順で声を変えて読みます（項目ごとに めたん から）。
音声がない項目は、端末の音声合成で読み上げます。

声：VOICEVOX:四国めたん・春日部つむぎ・雨晴はう・小夜/SAYO

### 解説を追加・修正したとき

1. `index.html` のデータを更新する
2. 読み上げ用テキストを取り出す（どちらか）

   ```
   node tools/extract.js "$PWD/index.html" tools/work/entries.json
   powershell -ExecutionPolicy Bypass -File tools\extract.ps1
   ```

3. VOICEVOX エンジン（http://localhost:50021）を動かして、音声を作る（ffmpeg も必要）。
   変わった項目だけ作り直し、使われなくなったファイルは削除される。

   ```
   python3 tools/voicevox.py
   ```

   読み間違いは `tools/yomi.json`（`["元の文字", "読ませる文字"]` の一覧）に足して直す。

4. `index.html` と `audio/` をコミットしてプッシュする

以前の Azure Speech（Nanami）の手順 `tools/tts.ps1` も残してあるが、実行すると Nanami の声に戻る。
