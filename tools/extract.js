const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage();
  await p.route(/^https?:/, r => r.abort());
  await p.goto('file://' + process.argv[2]);
  const out = await p.evaluate(() => { const o = [];
    for (const v in goshinshoData) goshinshoData[v].chapters.forEach(c => c.entries.forEach((e, i) => {
      if (e.content) o.push({ ref: v + "|" + c.name + "|" + i, title: e.title, chunks: ttsSplit(e.title + "。\n" + e.content) }); }));
    return o; });
  require('fs').writeFileSync(process.argv[3], JSON.stringify(out));
  console.log(out.length); await b.close();
})();
