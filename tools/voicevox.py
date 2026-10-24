# VOICEVOX で「解説付き」項目の音声（MP3）を作る。
# 一文ごとに 四国めたん → 春日部つむぎ → 雨晴はう → 小夜/SAYO の順で声を変えて読む（項目ごとに めたん から始める）。
#
# 準備: VOICEVOX エンジンを http://localhost:50021 で動かしておく（ffmpeg も必要）
#       tools/work/entries.json を作っておく（tools/extract.js または tools/extract.ps1）
#
# 使い方: python3 tools/voicevox.py
#   速く作りたいときは、エンジンをもう1つ動かし、後ろから作る2つめを同時に走らせる:
#   VOICEVOX_ENGINE=http://localhost:50022 python3 tools/voicevox.py --reverse
#
# 音声ファイル名は「声の順番＋読み上げ文」のハッシュ。解説を直した項目だけ作り直し、
# 変わっていない項目は再利用する。とちゅうで止まっても、もう一度実行すれば続きから作る。
# 読み間違いは tools/yomi.json（["元の文字", "読ませる文字"] の一覧）で直す。
import hashlib, json, os, subprocess, sys, tempfile, urllib.parse, urllib.request

VOICES = [("四国めたん", 2), ("春日部つむぎ", 8), ("雨晴はう", 10), ("小夜/SAYO", 46)]
ENGINE = os.environ.get("VOICEVOX_ENGINE", "http://localhost:50021")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(ROOT, "audio")


def post(path, body=None):
    req = urllib.request.Request(ENGINE + path, data=body, method="POST",
                                 headers={"Content-Type": "application/json"})
    return urllib.request.urlopen(req, timeout=300).read()


def fix(text, yomi):
    for a, b in yomi:
        text = text.replace(a, b)
    return text


def make(chunks, out_file):
    with tempfile.TemporaryDirectory() as tmp:
        names = []
        for i, t in enumerate(chunks):
            sid = VOICES[i % len(VOICES)][1]
            q = json.loads(post("/audio_query?" + urllib.parse.urlencode({"text": t, "speaker": sid})))
            q["postPhonemeLength"] = 0.35
            raw, norm = os.path.join(tmp, f"r{i:03d}.wav"), os.path.join(tmp, f"n{i:03d}.wav")
            with open(raw, "wb") as f:
                f.write(post(f"/synthesis?speaker={sid}", json.dumps(q).encode()))
            # キャラクターごとの声の大きさの差をそろえる
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", raw, "-af", "loudnorm=I=-18:TP=-1.5",
                            "-ar", "24000", "-ac", "1", norm], check=True)
            names.append(norm)
        lst = os.path.join(tmp, "list.txt")
        with open(lst, "w") as f:
            f.writelines(f"file '{n}'\n" for n in names)
        part = out_file + ".part"
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst,
                        "-b:a", "48k", "-f", "mp3", part], check=True)
        os.replace(part, out_file)


def main():
    with open(os.path.join(ROOT, "tools", "work", "entries.json"), encoding="utf-8-sig") as f:
        entries = json.load(f)
    with open(os.path.join(ROOT, "tools", "yomi.json"), encoding="utf-8") as f:
        yomi = json.load(f)
    order = "・".join(v[0] for v in VOICES)
    files, todo, made = {}, [], 0
    for n, e in enumerate(entries, 1):
        chunks = [fix(t, yomi) for t in e["chunks"]]
        h = hashlib.sha1(("voicevox|" + order + "|" + "\n".join(chunks)).encode()).hexdigest()[:16]
        name = h + ".mp3"
        path = os.path.join(AUDIO, name)
        files[e["ref"]] = "audio/" + name
        todo.append((n, e["title"], chunks, path))
    if "--reverse" in sys.argv:
        todo.reverse()
    for n, title, chunks, path in todo:
        if os.path.exists(path):
            continue
        # 同時に走っているもう1つが作っている項目はとばす
        try:
            os.close(os.open(path + ".lock", os.O_CREAT | os.O_EXCL))
        except FileExistsError:
            continue
        try:
            print(f"[{n}/{len(entries)}] {title}", flush=True)
            make(chunks, path)
            made += 1
        finally:
            os.remove(path + ".lock")
    if any(f.endswith(".lock") for f in os.listdir(AUDIO)):
        print("もう1つの実行がまだ作っています。終わったらもう一度実行して仕上げてください")
        return

    # 使われなくなった古い音声ファイルを片付ける
    used = {os.path.basename(v) for v in files.values()}
    for f in os.listdir(AUDIO):
        if f.endswith(".mp3") and f not in used:
            os.remove(os.path.join(AUDIO, f))

    with open(os.path.join(AUDIO, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump({"voice": "VOICEVOX:" + order, "files": files}, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"完了: 新規 {made} 件、再利用 {len(entries) - made} 件")


if __name__ == "__main__":
    sys.exit(main())
