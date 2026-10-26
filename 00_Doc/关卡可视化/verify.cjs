// Run with the bundled Node runtime. Uses installed Edge; all evidence stays here.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { pathToFileURL } = require('node:url');
const { chromium } = require('C:/Users/60550/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const evidence = path.join(__dirname, '_qa');
fs.mkdirSync(path.join(evidence, 'temp'), {recursive:true});
process.env.TEMP = process.env.TMP = path.join(evidence, 'temp');
(async () => {
  const context = await chromium.launchPersistentContext(path.join(evidence, 'browser-profile'), {
    executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
    headless: true, viewport: {width:1440,height:1080}, acceptDownloads:true,
    args:['--disable-crash-reporter','--no-first-run']
  });
  const errors = [], results = [];
  try {
    const page = await context.newPage();
    page.on('pageerror', e => errors.push(e.message));
    await page.goto(pathToFileURL(path.join(__dirname, 'index.html')).href);
    await page.waitForFunction(() => !!window.levelReview);
    for(const profile of ['ue','legacy']) {
      await page.selectOption('#profile',profile);
      const result = await page.evaluate(() => levelReview.checkLayout());
      assert.equal(result.passed,true,JSON.stringify(result));
      results.push(result);
    }
    await page.selectOption('#profile','ue');
    assert.equal(await page.evaluate(() => levelReview.move(-40,-21)),false,'Obstacle must block the player');
    assert.equal(await page.evaluate(() => levelReview.move(1000,0)),false,'Boundary must block the player');
    await page.locator('#map').focus();
    await page.keyboard.press('ArrowRight');
    assert.equal((await page.evaluate(() => levelReview.getState())).player.x,1);
    await page.click('[data-position="corner"]');
    const corner = await page.evaluate(() => ({state:levelReview.getState(),camera:levelReview.camera(),points:levelReview.spawnPoints()}));
    assert.ok(corner.camera.x < corner.state.player.x && corner.camera.y < corner.state.player.y);
    assert.ok(corner.points.length > 0);
    await page.click('#reset');
    await page.locator('[data-obstacle="A1"]').click();
    assert.match(await page.locator('#objectTitle').innerText(),/A1/);
    await page.click('#showAttack');
    await page.evaluate(() => levelReview.setTime(300));
    assert.match(await page.locator('#bossText').innerText(),/10 秒/);
    await page.evaluate(() => levelReview.setTime(310));
    assert.match(await page.locator('#bossText').innerText(),/Boss 战/);
    await page.evaluate(() => levelReview.setTime(360));
    assert.match(await page.locator('#eventText').innerText(),/计划刷新 4 只/);
    await page.click('#play');
    await page.waitForFunction(() => levelReview.getState().time > 360);
    await page.click('#play');
    await page.click('[data-tab="beats"]');
    assert.equal(await page.locator('#beatTable tbody tr').count(),7);
    await page.click('[data-tab="rules"]');
    assert.equal(await page.locator('#ruleTable tbody tr').count(),14);
    await page.click('[data-filter="aligned"]');
    assert.equal(await page.locator('#ruleTable tbody tr').count(),10);
    await page.click('[data-filter="pending"]');
    assert.equal(await page.locator('#ruleTable tbody tr').count(),4);
    await page.click('[data-filter="all"]');
    await page.screenshot({path:path.join(evidence,'rules-desktop.png'),fullPage:true});
    await page.click('[data-tab="build"]');
    await page.click('#checkLayout');
    assert.match(await page.locator('#checkResult').innerText(),/^通过/);
    const downloadPromise=page.waitForEvent('download');
    await page.click('#download');
    const download=await downloadPromise;
    const exportPath=path.join(__dirname,'layout-review-data.json');
    await download.saveAs(exportPath);
    const exported=JSON.parse(fs.readFileSync(exportPath,'utf8'));
    assert.equal(exported.obstacles.length,8);
    assert.equal(exported.boss.appearance,310);
    assert.equal(exported.height,107.6);
    const cpp=fs.readFileSync(path.resolve(__dirname,'../../02_Prototype/AlchemyHD2D/Source/AlchemyHD2D/AlchemyWorld.cpp'),'utf8');
    const rects=[...cpp.matchAll(/FVector4\((-?\d+),(-?\d+),(\d+),(\d+)\)/g)].map(m=>m.slice(1).map(Number));
    assert.deepEqual(rects,exported.obstacles.map(o=>[o.x,o.y,o.w,o.h]),'HTML coordinates must match the UE layout source');
    const sourceLinks=await page.locator('.source-list a').evaluateAll(as=>as.map(a=>a.getAttribute('href')));
    for(const href of sourceLinks) assert.ok(fs.existsSync(path.resolve(__dirname,href)),href);
    await page.click('[data-tab="layout"]');
    await page.click('#reset');
    await page.uncheck('#showAttack');
    await page.evaluate(()=>levelReview.setTime(270));
    await page.screenshot({path:path.join(evidence,'layout-desktop.png'),fullPage:true});
    await page.setViewportSize({width:390,height:844});
    await page.screenshot({path:path.join(evidence,'layout-mobile.png'),fullPage:true});
    assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth+1),'Page should fit mobile width');
    assert.deepEqual(errors,[],'No browser JavaScript errors');
    fs.writeFileSync(path.join(evidence,'verification.json'),JSON.stringify({passed:true,checkedAt:new Date().toISOString(),results,errors,checks:['both layout scales','all nine location presets spawn coverage','collision and boundaries','keyboard movement','camera clamping','obstacle selection','300/310/360 time events','play/pause','four tabs','rule filters 14/10/4','JSON download','source link targets','mobile width','offline file URL']},null,2));
    console.log(JSON.stringify({passed:true,results,errors,evidence},null,2));
  } finally { await context.close(); }
})().catch(e=>{console.error(e);process.exitCode=1});
