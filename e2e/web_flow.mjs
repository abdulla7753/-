import { chromium } from 'playwright';
const lang = process.argv[2] || 'ar';
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 800 }, locale: lang === 'ar' ? 'ar-QA' : 'en-US' });
page.on('pageerror', e => console.log('PAGEERROR', e.message.slice(0, 400)));
const shot = async (n) => { await page.waitForTimeout(800); await page.screenshot({ path: `${lang}_${n}.png` }); console.log('shot', n); };
await page.goto('http://localhost:8080/');
await page.waitForTimeout(8000);
await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
await page.waitForTimeout(800);
const T = lang === 'ar'
  ? { lang: 'English', newp: 'مشروع جديد', create: 'إنشاء', sim: 'المحاكاة', run: /محاكاة \(/, results: 'النتائج', mode: 'المحاكاة', play: 'تشغيل', heat: 'خريطة الازدحام الحرارية', design: 'التصميم', roadTool: 'طريق' }
  : { lang: 'العربية', newp: 'New project', create: 'Create', sim: 'Simulate', run: /Simulate \(/, results: 'Results', mode: 'Simulation', play: 'Play', heat: 'Congestion heat map', design: 'Design', roadTool: 'Road' };
if (lang === 'en') { await page.getByRole('button', { name: 'English' }).click(); await page.waitForTimeout(1500); }
await page.getByRole('button', { name: T.newp }).click();
await shot('02_new_project_dialog');
await page.getByRole('button', { name: T.create }).click();
await page.waitForTimeout(2500);
await shot('03_workspace_design');
await page.getByRole('tab', { name: T.sim }).click();
await shot('04_sim_panel');
await page.getByRole('button', { name: T.run }).click();
await page.waitForTimeout(1500);
await shot('05_running');
// wait for completion (5 replications x 1 h simulated)
for (let i = 0; i < 120; i++) {
  await page.waitForTimeout(1000);
  const done = await page.getByRole('tab', { name: T.results }).isVisible().catch(() => false);
  const txt = await page.evaluate(() => document.body.innerText);
  if (/اكتملت المحاكاة|Simulation finished|لم تكتمل|did not complete/.test(txt)) break;
}
await shot('06_done');
await page.getByRole('tab', { name: T.results }).click();
await shot('07_results');
// Playback of the simulated vehicles (layout mirrors in Arabic).
const rtl = lang === 'ar';
const X = (x) => rtl ? 1280 - x : x;
const C = rtl ? { centre: 825, play: 1239, heat: 451, colour: 411, design: 917 } : { centre: 418, play: 41, heat: 829, colour: 869, design: 383 };
await page.getByRole('button', { name: T.mode }).first().click();
await page.waitForTimeout(1500);
// zoom into the junction
for (let i = 0; i < 3; i++) { await page.mouse.move(C.centre, 428); await page.mouse.wheel(0, -200); await page.waitForTimeout(60); }
await page.mouse.click(C.play, 760);   // play
await page.waitForTimeout(7000);
await shot('09_playback_running');
await page.mouse.click(C.heat, 760);  // heat map
await page.waitForTimeout(800);
await shot('10_heatmap');
await page.mouse.click(C.heat, 760);
await page.mouse.click(C.colour, 760);  // colour by speed
await page.waitForTimeout(800);
await shot('10b_speed_colours');
await page.mouse.click(C.play, 760);   // pause
// Back to design: select a road and draw a new one.
await page.mouse.click(C.design, 28);
await page.waitForTimeout(1200);
await shot('11_design_zoomed');
await page.mouse.click(36, 120);   // Select tool (left rail)
await browser.close();
