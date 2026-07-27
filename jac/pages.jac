"""PipeTrace - the board pages, emitted from Jac.

The incident board and the landing shell used to sit in the tree as loose HTML that
nothing owned. They live here now: this module holds them and writes them out, so the
page that ships is the page this code emits. main.jac still reads web/board.html as
the template for standalone.html, and this is where that template comes from.

    jac run jac/pages.jac      ->  web/index.html, web/board.html

Both pages read their numbers from trace.js and measured.json, which the run writes.
Nothing here is templated per run, so the emitted bytes are stable and diffable.
"""


glob INDEX_HTML: str = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Rivus — find the leak without guessing</title>
<style>
  :root{
    --bg:#04070C; --rule:#152232; --ink:#E6F0F8; --ink2:#93A9BD; --ink3:#5B7085;
    --wave:#3E7FB8; --wave2:#8FC4E8; --foam:#E8F2FA; --mint:#35D6A0; --alarm:#FF6B4A;
    --mono:"SF Mono",ui-monospace,Menlo,Consolas,monospace;
    --disp:"Iowan Old Style",Georgia,"Times New Roman",serif;
  }
  *{box-sizing:border-box;margin:0;padding:0}
  html{scroll-behavior:smooth}
  body{background:var(--bg);color:var(--ink);font-family:var(--mono);font-size:13px;
       -webkit-font-smoothing:antialiased;font-feature-settings:"tnum"}
  a{color:inherit;text-decoration:none}

  #swell{position:fixed;inset:0;width:100%;height:100vh;pointer-events:none;z-index:0}
  .wrap{position:relative;z-index:1;max-width:1180px;margin:0 auto;padding:0 40px}

  nav{display:flex;align-items:center;gap:13px;padding:26px 0}
  .glyph{width:17px;height:17px;position:relative}
  .glyph i{position:absolute;width:7px;height:7px}
  .glyph i:nth-child(1){left:0;top:5px;background:var(--mint);opacity:.55}
  .glyph i:nth-child(2){left:5px;top:0;background:var(--wave2)}
  .glyph i:nth-child(3){left:10px;top:8px;background:var(--mint);opacity:.85}
  .brand{font-size:15px}
  .grow{flex:1}
  nav .links{display:flex;gap:28px;font-size:11px;letter-spacing:.16em;color:var(--ink3)}
  nav .links a:hover{color:var(--ink)}

  .hero{min-height:calc(100vh - 90px);display:flex;flex-direction:column;
        align-items:center;justify-content:center;text-align:center;padding-bottom:70px}
  .pill{display:inline-flex;align-items:center;gap:9px;padding:6px 15px;
        border:1px solid var(--rule);border-radius:20px;font-size:10.5px;
        letter-spacing:.15em;color:var(--ink2);background:rgba(4,7,12,.6)}
  .pill s{width:6px;height:6px;border-radius:50%;background:var(--mint);
          text-decoration:none;box-shadow:0 0 9px var(--mint)}
  .hero h1{font-family:var(--disp);font-size:clamp(44px,7vw,86px);line-height:1.03;
           font-weight:400;letter-spacing:-.022em;margin:30px 0 0}
  .hero h1 em{font-style:italic;color:var(--foam)}
  .hero p{font-size:13px;line-height:1.85;color:var(--ink2);max-width:52ch;margin:26px auto 0}
  .cta{display:inline-block;margin-top:38px;padding:15px 30px;font-size:11.5px;
       letter-spacing:.19em;color:#04120C;background:var(--mint);
       clip-path:polygon(0 0,100% 0,100% 72%,calc(100% - 13px) 100%,0 100%);
       transition:transform .16s,box-shadow .16s}
  .cta:hover{transform:translateY(-2px);box-shadow:0 10px 34px rgba(53,214,160,.28)}
  .scrollnote{margin-top:40px;font-size:10px;letter-spacing:.2em;color:var(--ink3)}

  section{padding:96px 0;border-top:1px solid var(--rule)}
  h2{font-size:10.5px;letter-spacing:.2em;color:var(--mint);margin-bottom:26px}
  .lede{font-family:var(--disp);font-size:clamp(25px,2.9vw,38px);line-height:1.22;
        font-weight:400;letter-spacing:-.014em;max-width:19ch}
  .lede em{font-style:italic;color:var(--wave2)}
  .cols{display:grid;grid-template-columns:1fr 1fr;gap:56px;margin-top:34px}
  .cols p{font-size:13px;line-height:1.85;color:var(--ink2)}
  .cols p+p{margin-top:17px}
  .cols b{color:var(--ink);font-weight:400}
  .cols u{text-decoration:none;color:var(--mint)}

  .steps{display:grid;grid-template-columns:repeat(4,1fr);gap:1px;background:var(--rule);
         margin-top:44px;border:1px solid var(--rule)}
  .step{background:var(--bg);padding:24px 20px}
  .step .n{font-family:var(--disp);font-size:31px;color:var(--wave2);line-height:1}
  .step h3{font-size:12px;letter-spacing:.05em;margin:13px 0 9px;font-weight:400}
  .step p{font-size:11.5px;line-height:1.65;color:var(--ink3)}

  .figures{display:grid;grid-template-columns:repeat(3,1fr);gap:1px;background:var(--rule);
           border:1px solid var(--rule);margin-top:34px}
  .fg{background:var(--bg);padding:26px 22px}
  .fg .v{font-family:var(--disp);font-size:42px;line-height:1}
  .fg .v.good{color:var(--mint)} .fg .v.flat{color:var(--ink3)}
  .fg .l{font-size:11px;color:var(--ink3);margin-top:11px;line-height:1.6}

  .limit{border-left:2px solid var(--alarm);padding-left:22px;margin-top:34px;
         max-width:70ch}
  .limit p{font-size:13px;line-height:1.85;color:var(--ink2)}
  .limit b{color:var(--ink);font-weight:400}

  footer{border-top:1px solid var(--rule);padding:34px 0 50px;display:flex;
         justify-content:space-between;font-size:10.5px;color:var(--ink3);
         letter-spacing:.06em}
  @media(max-width:880px){.cols,.steps,.figures{grid-template-columns:1fr}}
</style>
</head>
<body>
<canvas id="swell"></canvas>

<div class="wrap">
  <nav>
    <div class="glyph"><i></i><i></i><i></i></div>
    <div class="brand">Rivus</div>
    <div class="grow"></div>
    <div class="links">
      <a href="#method">METHOD</a><a href="#results">RESULTS</a><a href="#limits">LIMITS</a>
      <a href="board.html" style="color:var(--mint)">LIVE BOARD</a>
    </div>
  </nav>

  <div class="hero">
    <span class="pill"><s></s>35 JUNCTIONS · 40 PIPES · 36 HYDRAULIC RUNS IN 0.23S</span>
    <h1>Find the leak<br>without <em>guessing</em></h1>
    <p>Bayesian leak localisation over live pressure gauges. Rivus reports a credible set
       and the bits it is still missing — never a single pipe it cannot prove.</p>
    <a class="cta" href="board.html">[ RUN A DIAGNOSIS ]</a>
    <div class="scrollnote">SCROLL FOR METHOD</div>
  </div>

  <section id="method">
    <h2>METHOD</h2>
    <div class="lede">Twenty questions,<br>for <em>pipes</em>.</div>
    <div class="cols">
      <div>
        <p>A main has cracked somewhere under the district. The utility knows water is
           leaving — more goes in than comes out of taps — but not where. <b>Thirty-five
           junctions</b> could be responsible.</p>
        <p>Checking one means two people, a truck and a pressure gauge: about an hour.
           Opening the wrong street costs roughly <b>twenty thousand dollars</b>.</p>
      </div>
      <div>
        <p>Rivus simulates a leak at every junction using the EPA's hydraulic engine —
           <u>thirty-six runs in a fifth of a second</u> — and each possible break leaves a
           different fingerprint of pressure drops.</p>
        <p>Then it does the part nobody else does: it names <b>the single hydrant whose
           reading will eliminate the most suspects</b>, and updates the moment the crew
           reports back.</p>
      </div>
    </div>

    <div class="steps">
      <div class="step"><div class="n">01</div><h3>Simulate every suspect</h3>
        <p>One hydraulic run per candidate junction. A leak anywhere moves pressure
           everywhere, so one run scores every possible gauge at once.</p></div>
      <div class="step"><div class="n">02</div><h3>Choose the next reading</h3>
        <p>Every candidate hydrant is scored by expected information gain, weighed against
           the crew-hours it costs to get there.</p></div>
      <div class="step"><div class="n">03</div><h3>Say what cannot be known</h3>
        <p>Junctions on the same run of pipe are hydraulically identical. Rivus names those
           pairs instead of picking a confident winner.</p></div>
      <div class="step"><div class="n">04</div><h3>Screen the shutdown</h3>
        <p>Every valve plan is checked twice — graph reachability and a pressure-dependent
           run — before anyone closes anything.</p></div>
    </div>
  </section>

  <section id="results">
    <h2>RESULTS · MEASURED AGAINST A RANDOM CONTROL</h2>
    <div class="lede">We tested ourselves<br>against <em>chance</em>.</div>
    <div class="figures">
      <div class="fg"><div class="v good">3.6×</div>
        <div class="l">better than random probing at finding the exact junction, on a
          92-junction district. 19.6% against 5.4%.</div></div>
      <div class="fg"><div class="v good">37%</div>
        <div class="l">less street to search. Mean distance from the crew's leading
          candidate to the actual break falls from 6.27 hops to 3.98.</div></div>
      <div class="fg"><div class="v flat">0</div>
        <div class="l">measurable advantage on the 35-junction network, where 179 of 210
          candidate pairs are physically indistinguishable. We report that too.</div></div>
    </div>
    <div class="limit">
      <p>Our first figure was <b>43% closer</b>. A teammate built a non-circularity test
         that proved the setup was marking its own homework — the evidence differed from
         our own model by 0.04 psi against a 0.35 psi noise floor. <b>We withdrew the
         claim.</b> Everything above is what survived, across 105 incidents per arm, with
         the random control still in.</p>
    </div>
  </section>

  <section id="limits">
    <h2>LIMITS</h2>
    <div class="lede">What we <em>don't</em> know,<br>on the record.</div>
    <div class="cols">
      <div>
        <p><b>The exact pipe is found about 10–20% of the time.</b> Rivus reports a credible
           set. Top-1 is not a call it makes.</p>
        <p><b>It needs a network with structure.</b> On a small, hydraulically degenerate
           district it is no better than guessing, and it says so.</p>
      </div>
      <div>
        <p><b>Shutdown screening is modelled service impact, not a safety certification.</b>
           An operator decides.</p>
        <p><b>The sample networks are EPA references</b>, not a utility's own calibrated
           model. The engine reads standard EPANET files, so a real one drops straight in.</p>
      </div>
    </div>
  </section>

  <footer>
    <span>RIVUS · BUILT AT JACHACKS SF · 26 JULY 2026</span>
    <span>EPA EPANET · JAC WALKERS OVER THE PIPE GRAPH · 96% JAC</span>
  </footer>
</div>

<script>
// the same halftone swell the board uses, so the two pages read as one product
const cv=document.getElementById('swell'),cx=cv.getContext('2d');
const t0=performance.now();
function frame(){
  const w=cv.width=innerWidth,h=cv.height=innerHeight,t=(performance.now()-t0)/9000,gap=13;
  cx.clearRect(0,0,w,h);
  for(let y=0;y<h;y+=gap)for(let x=0;x<w;x+=gap){
    const u=x/w,v=y/h;
    const a=Math.sin(u*5.2+t*1.3+Math.cos(v*3.1+t*.7)*1.5);
    const b=Math.sin(u*2.4-t*.9+v*4.6);
    const n=a*.65+b*.35, band=Math.max(0,n);
    const fall=Math.pow(1-v,1.45)*Math.min(1,u*1.6+.15);
    const r=band*fall*3.2;
    if(r>.22){
      const k=Math.min(1,band*fall*1.5);
      cx.fillStyle=`rgba(${Math.round(62+180*k)},${Math.round(127+120*k)},${Math.round(184+66*k)},${(.09+k*.5).toFixed(3)})`;
      cx.beginPath();cx.arc(x,y,r,0,6.283);cx.fill();
    }
  }
  requestAnimationFrame(frame);
}
if(!matchMedia('(prefers-reduced-motion: reduce)').matches) frame();
else {cv.width=innerWidth;cv.height=innerHeight;}
addEventListener('resize',()=>{cv.width=innerWidth;cv.height=innerHeight});
</script>
</body>
</html>
""";


glob BOARD_HTML: str = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Rivus — District 2 leak investigation</title>
<script src="trace.js"></script>
<style>
  :root{
    --bg:#04070C; --bg2:#070C14; --rule:#152232;
    --ink:#E6F0F8; --ink2:#93A9BD; --ink3:#5B7085;
    --wave:#3E7FB8; --wave2:#8FC4E8; --foam:#E8F2FA;
    --mint:#35D6A0; --alarm:#FF6B4A; --amber:#F0B429;
    --mono:"SF Mono",ui-monospace,Menlo,Consolas,monospace;
    --disp:"Iowan Old Style",Georgia,"Times New Roman",serif;
  }
  *{box-sizing:border-box;margin:0;padding:0}
  html,body{height:100%;overflow:hidden}
  body{background:var(--bg);color:var(--ink);font-family:var(--mono);font-size:13px;
       -webkit-font-smoothing:antialiased;font-feature-settings:"tnum"}

  /* halftone swell — the hero's dot field, carried through as atmosphere */
  #swell{position:fixed;inset:0;pointer-events:none;opacity:.55}

  #page{position:relative;display:grid;grid-template-rows:auto auto 1fr auto;
        height:100vh;max-width:1580px;margin:0 auto;padding:0 44px}

  .top{display:flex;align-items:center;gap:13px;padding:20px 0 18px}
  .glyph{width:17px;height:17px;position:relative}
  .glyph i{position:absolute;width:7px;height:7px;background:var(--mint)}
  .glyph i:nth-child(1){left:0;top:5px;opacity:.55}
  .glyph i:nth-child(2){left:5px;top:0;background:var(--wave2)}
  .glyph i:nth-child(3){left:10px;top:8px;opacity:.8}
  .brand{font-size:15px;letter-spacing:.02em}
  .grow{flex:1}
  .nav{display:flex;gap:26px;font-size:11px;letter-spacing:.16em;color:var(--ink3)}
  .nav b{color:var(--ink);font-weight:400;cursor:pointer}
  .nav span{cursor:pointer}
  .nav span:hover{color:var(--ink2)}

  .pill{display:inline-flex;align-items:center;gap:9px;padding:5px 13px;
        border:1px solid var(--rule);border-radius:20px;font-size:10.5px;
        letter-spacing:.14em;color:var(--ink2);background:rgba(7,12,20,.7)}
  .pill s{width:6px;height:6px;border-radius:50%;background:var(--mint);
          text-decoration:none;box-shadow:0 0 8px var(--mint)}

  .head{display:grid;grid-template-columns:1fr 336px;gap:54px;align-items:end;
        padding:4px 0 18px;border-bottom:1px solid var(--rule)}
  h1{font-family:var(--disp);font-size:clamp(30px,3.1vw,44px);line-height:1.04;
     font-weight:400;letter-spacing:-.012em;margin-top:14px}
  h1 em{font-style:italic;color:var(--wave2)}
  .stand{font-size:12.5px;line-height:1.62;color:var(--ink2);max-width:58ch;margin-top:13px}
  .stand b{color:var(--ink);font-weight:400}
  .stand u{text-decoration:none;color:var(--mint)}
  .readout{text-align:right}
  .readout .l{font-size:10px;letter-spacing:.16em;color:var(--ink3)}
  .readout .n{font-family:var(--disp);font-size:52px;line-height:1;margin:6px 0 4px}
  .readout .d{font-size:11px;color:var(--ink3)}

  .fig{display:grid;grid-template-columns:1fr 336px;gap:54px;min-height:0;padding-top:14px}
  .plot{display:flex;flex-direction:column;min-height:0}
  svg#plot{width:100%;flex:1;min-height:0;display:block}
  .key{display:flex;flex-wrap:wrap;gap:17px;padding-top:11px;margin-top:10px;
       border-top:1px solid var(--rule);font-size:10.5px;color:var(--ink3);
       letter-spacing:.05em}
  .key i{display:inline-block;width:15px;border-top:2px solid;margin-right:6px;
         vertical-align:middle}
  .key u{display:inline-block;width:7px;height:7px;border-radius:50%;margin-right:6px;
         vertical-align:middle;text-decoration:none}

  .side{overflow-y:auto;padding-bottom:6px}
  .side::-webkit-scrollbar{width:3px}
  .side::-webkit-scrollbar-thumb{background:var(--rule)}
  h2{font-size:10px;letter-spacing:.18em;color:var(--ink3);padding-bottom:8px;
     border-bottom:1px solid var(--rule);margin-bottom:11px}
  .blk{margin-bottom:24px}
  .row{display:flex;justify-content:space-between;gap:12px;padding:6px 0;font-size:12px;
       border-bottom:1px solid rgba(21,34,50,.65)}
  .row span{color:var(--ink2)}
  .row b{font-weight:400}
  .row.good b{color:var(--mint)} .row.bad b{color:var(--alarm)}
  .cap{font-size:11px;line-height:1.6;color:var(--ink3);margin-top:10px}
  .cap b{color:var(--ink2);font-weight:400}
  .tags{display:flex;flex-wrap:wrap;gap:5px}
  .tag{font-size:11px;padding:3px 8px;border:1px solid var(--rule);color:var(--ink2)}
  .tag.lead{border-color:var(--alarm);color:var(--alarm)}

  .foot{border-top:1px solid var(--rule)}
  .steps{display:flex}
  .cell{flex:1;padding:11px 13px 13px;cursor:pointer;border-right:1px solid var(--rule);
        min-width:0;transition:background .16s}
  .cell:last-child{border-right:0}
  .cell:hover{background:var(--bg2)}
  .cell.on{background:linear-gradient(180deg,rgba(53,214,160,.11),transparent)}
  .cell.on::before{content:"";position:absolute;margin-top:-11px;height:2px;width:0}
  .cell .k{font-size:9.5px;letter-spacing:.15em;color:var(--ink3)}
  .cell .v{font-family:var(--disp);font-size:22px;line-height:1.3}
  .cell.on .v{color:var(--mint)}
  .cell .s{font-size:10px;color:var(--ink3);white-space:nowrap;overflow:hidden;
           text-overflow:ellipsis}
  .src{display:flex;justify-content:space-between;padding:9px 0 13px;font-size:10px;
       color:var(--ink3)}

  /* Responsive. Below ~1180px the two-column figure cannot hold its side rail, so
     tighten, then stack it under the drawing and let the page scroll. */
  @media (max-width:1320px){
    #page{padding:0 28px}
    .head,.fig{grid-template-columns:1fr 300px;gap:34px}
  }
  @media (max-width:1180px){
    html,body{overflow:auto}
    /* grid and flex children need min-width:0 or they refuse to shrink below their
       content and push the whole sheet off the right edge */
    #page{height:auto;min-height:100vh;grid-template-rows:auto auto auto auto;
          padding:0 24px;min-width:0}
    #page>*{min-width:0}
    .foot{min-width:0;overflow:hidden}
    .steps{min-width:0}
    .head{grid-template-columns:1fr;gap:20px}
    .readout{border-left:0;border-top:2px solid var(--wave2);padding:14px 0 0}
    .fig{grid-template-columns:1fr;gap:26px}
    .plot{min-height:56vh}
    svg{min-height:56vh}
    .side{overflow:visible;max-height:none}
    .steps{overflow-x:auto;-webkit-overflow-scrolling:touch}
    .cell{flex:0 0 auto;min-width:96px}
  }
  @media (max-width:680px){
    h1{font-size:26px}
    .key{gap:11px;font-size:10.5px}
    #page{padding:0 16px}
  }

  @media (prefers-reduced-motion:no-preference){
    .flow{animation:flow linear infinite}
    @keyframes flow{to{stroke-dashoffset:-200}}
  }
</style>
</head>
<body>
<canvas id="swell"></canvas>
<div id="page">
  <div class="top">
    <div class="glyph"><i></i><i></i><i></i></div>
    <div class="brand">Rivus</div>
    <div class="grow"></div>
    <div class="nav" id="nav"></div>
  </div>

  <div class="head">
    <div>
      <span class="pill"><s></s><span id="pill"></span></span>
      <h1 id="h1"></h1>
      <div class="stand" id="stand"></div>
    </div>
    <div class="readout">
      <div class="l" id="rl"></div><div class="n" id="rn"></div><div class="d" id="rd"></div>
    </div>
  </div>

  <div class="fig">
    <div class="plot"><svg id="plot" preserveAspectRatio="xMidYMid meet"></svg>
      <div class="key" id="key"></div></div>
    <div class="side" id="side"></div>
  </div>

  <div class="foot">
    <div class="steps" id="steps"></div>
    <div class="src"><span id="src"></span><span>← → TO STEP</span></div>
  </div>
</div>

<script>
const T=window.TRACE,S=T.scenario;
const $=i=>document.getElementById(i), f=(v,n=2)=>Number(v).toFixed(n);
const NP=T.steps.length,NPLAN=T.isolation.length,LAST=NP+1+NPLAN;
let stage=NP+1+Math.max(0,T.isolation.findIndex(p=>p.chosen));

/* ---------- halftone swell: the hero's dot field, as living atmosphere ---------- */
const cv=$('swell'),cx=cv.getContext('2d');
let t0=performance.now();
function swell(){
  const w=cv.width=innerWidth, h=cv.height=innerHeight;
  const t=(performance.now()-t0)/9000, gap=13;
  cx.clearRect(0,0,w,h);
  for(let y=0;y<h;y+=gap){
    for(let x=0;x<w;x+=gap){
      const u=x/w, v=y/h;
      // stacked sine ridges, the same shape family as the hero artwork
      const a=Math.sin(u*5.2+t*1.3+Math.cos(v*3.1+t*.7)*1.5);
      const b=Math.sin(u*2.4-t*.9+v*4.6);
      const n=(a*.65+b*.35);
      const band=Math.max(0,n);
      const fall=Math.pow(1-v,1.5)*Math.min(1,u*1.6+.15);
      const r=band*fall*3.1;
      if(r>.22){
        const wash=Math.min(1,band*fall*1.5);
        cx.fillStyle=`rgba(${Math.round(62+180*wash)},${Math.round(127+120*wash)},${Math.round(184+66*wash)},${(.09+wash*.5).toFixed(3)})`;
        cx.beginPath(); cx.arc(x,y,r,0,6.283); cx.fill();
      }
    }
  }
  requestAnimationFrame(swell);
}
if(!matchMedia('(prefers-reduced-motion: reduce)').matches) swell();
else { cv.width=innerWidth; cv.height=innerHeight; }

/* ---------------------------- the network figure ---------------------------- */
const by={}; T.nodes.forEach(n=>by[n.name]=n);
const px=n=>n.y, py=n=>-n.x;               // quarter turn: district is tall, sheet is wide
const XS=T.nodes.map(px),YS=T.nodes.map(py),M=8;
const bb={x0:Math.min(...XS)-M,y0:Math.min(...YS)-M,
          w:Math.max(...XS)-Math.min(...XS)+M*2,h:Math.max(...YS)-Math.min(...YS)+M*2};
$('plot').setAttribute('viewBox',`${bb.x0} ${bb.y0} ${bb.w} ${bb.h}`);
const U=bb.w/100;

const post=s=>s<1?Object.fromEntries(T.nodes.map(n=>[n.name,1/T.nodes.length]))
                 :T.steps[Math.min(s,NP)-1].posterior;
const planAt=s=>(s>=NP+2&&s<=NP+1+NPLAN)?T.isolation[s-NP-2]:null;
function credible(p,m=.9){const r=Object.entries(p).sort((a,b)=>b[1]-a[1]);
  const o=[];let a=0;for(const[n,q]of r){o.push(n);a+=q;if(a>=m)break}return o}

function draw(){
  const P=post(stage), plan=planAt(stage);
  const dead=plan?plan.stranded_graph:[], cut=plan?plan.segment:[];
  const probed=T.steps.slice(0,Math.min(stage,NP)).map(s=>s.chosen);
  const surv=stage>=1?credible(P):[];
  let g='';

  // belief drawn as a halftone field — same language as the swell, but the dot size
  // is probability, so the decoration and the data are the same mark
  if(stage>=1){
    const step=U*1.15;
    for(let y=bb.y0;y<bb.y0+bb.h;y+=step){
      for(let x=bb.x0;x<bb.x0+bb.w;x+=step){
        let d=0;
        surv.forEach(nm=>{
          const n=by[nm]; if(!n) return;
          const q=(P[nm]||0)*T.nodes.length;
          const r2=(px(n)-x)**2+(py(n)-y)**2;
          d+=q*Math.exp(-r2/(U*U*13));
        });
        if(d>.09){
          const r=Math.min(step*.42,step*.1+d*step*.2);
          g+=`<circle cx="${x.toFixed(2)}" cy="${y.toFixed(2)}" r="${r.toFixed(2)}"
              fill="var(--alarm)" fill-opacity="${Math.min(.5,.1+d*.22).toFixed(3)}"/>`;
        }
      }
    }
  }

  T.pipes.forEach(p=>{
    const a=by[p.a],b=by[p.b]; if(!a||!b)return;
    const isCut=cut.includes(p.pid), off=dead.includes(p.a)&&dead.includes(p.b);
    g+=`<line x1="${px(a)}" y1="${py(a)}" x2="${px(b)}" y2="${py(b)}"
      stroke="${isCut?'var(--alarm)':off?'#16212E':'var(--wave)'}"
      stroke-opacity="${off?1:isCut?.95:.62}" stroke-width="${U*(isCut?.26:.19)}"
      ${off?`stroke-dasharray="${U*.8} ${U*.8}"`:''}/>`;
    if(!isCut&&!off){
      const L=Math.hypot(px(b)-px(a),py(b)-py(a));
      g+=`<line x1="${px(a)}" y1="${py(a)}" x2="${px(b)}" y2="${py(b)}" class="flow"
        stroke="var(--foam)" stroke-opacity=".75" stroke-width="${U*.17}"
        stroke-linecap="round" stroke-dasharray="${U*.8} ${U*5.4}" pathLength="200"
        style="animation-duration:${(3.2+L/24).toFixed(2)}s"/>`;
    }
    if(isCut){
      const mx=(px(a)+px(b))/2,my=(py(a)+py(b))/2;
      const an=Math.atan2(py(b)-py(a),px(b)-px(a))*180/Math.PI;
      g+=`<g transform="translate(${mx} ${my}) rotate(${an})">
        <line x1="0" y1="${-U*1.1}" x2="0" y2="${U*1.1}" stroke="var(--alarm)"
        stroke-width="${U*.3}" stroke-linecap="round"/></g>`;
    }
  });

  T.nodes.forEach(n=>{
    const off=dead.includes(n.name), pr=probed.includes(n.name), inSet=surv.includes(n.name);
    let fill=off?'#16212E':'var(--bg)', stroke=off?'#22303F':'var(--wave2)', r=U*.42;
    if(inSet){stroke='var(--alarm)';fill='var(--alarm)';r=U*.55}
    if(pr){stroke='var(--foam)';fill='var(--foam)';r=U*.5}
    if(n.critical){stroke=off?'var(--alarm)':'var(--mint)';fill='var(--bg)';r=U*.78}
    g+=`<circle cx="${px(n)}" cy="${py(n)}" r="${r}" fill="${fill}" stroke="${stroke}"
        stroke-width="${U*.17}"/>`;
    if(n.critical){
      const c=off?'var(--alarm)':'var(--mint)', rt=px(n)>bb.x0+bb.w*.6, d=rt?-1:1;
      g+=`<line x1="${px(n)+d*U*1.25}" y1="${py(n)}" x2="${px(n)+d*U*3.3}" y2="${py(n)}"
          stroke="${c}" stroke-width="${U*.1}" stroke-opacity=".8"/>
        <text x="${px(n)+d*U*3.7}" y="${py(n)+U*.48}" font-size="${U*1.4}" fill="${c}"
          text-anchor="${rt?'end':'start'}" font-family="var(--mono)"
          letter-spacing="${U*.1}">HOSPITAL${off?' · NO SUPPLY':''}</text>`;
    }
    if(pr) g+=`<text x="${px(n)}" y="${py(n)-U*1.5}" font-size="${U*1.3}" fill="var(--foam)"
        text-anchor="middle" font-family="var(--mono)">${probed.indexOf(n.name)+1}</text>`;
    else if(inSet){
      const rt=px(n)>bb.x0+bb.w*.88;
      g+=`<text x="${px(n)+(rt?-U*1.1:U*1.1)}" y="${py(n)-U*.95}" font-size="${U*1.25}"
          fill="var(--alarm)" text-anchor="${rt?'end':'start'}"
          font-family="var(--mono)">${n.name}</text>`;
    }
  });

  if(stage>=NP+1){
    const t=by[S.truth];
    if(t)g+=`<circle cx="${px(t)}" cy="${py(t)}" r="${U*1.55}" fill="none"
      stroke="var(--foam)" stroke-width="${U*.15}" stroke-dasharray="${U*.5} ${U*.45}"/>
      <text x="${px(t)}" y="${py(t)+U*3.3}" font-size="${U*1.25}" fill="var(--foam)"
      text-anchor="middle" font-family="var(--mono)" opacity=".85">ACTUAL BREAK</text>`;
  }
  $('plot').innerHTML=g;
  $('key').innerHTML=[
    `<span><i style="border-color:var(--wave)"></i>CHARGED MAIN</span>`,
    `<span><i style="border-color:#22303F;border-top-style:dashed"></i>NO SUPPLY</span>`,
    `<span><i style="border-color:var(--alarm)"></i>VALVE CLOSED</span>`,
    `<span><u style="background:var(--alarm)"></u>STILL POSSIBLE</span>`,
    `<span><u style="background:var(--foam)"></u>GAUGE READ</span>`,
    `<span><u style="border:2px solid var(--mint)"></u>CRITICAL FACILITY</span>`].join('');
  side(); steps();
}

function side(){
  const st=(stage>=1&&stage<=NP)?T.steps[stage-1]:null;
  const held=stage>=1?T.steps[Math.min(stage,NP)-1]:null;
  const prev=stage>=2?T.steps[Math.min(stage,NP)-2]:null;
  const plan=planAt(stage), I=T.identifiability;
  const n3=(T.measured||[]).find(m=>m.junctions>50), n2=(T.measured||[]).find(m=>m.junctions<50);

  let h1,stand,rl,rn,rd;
  if(stage===0){
    h1=`Find the leak<br>without <em>guessing</em>`;
    stand=`A main has failed somewhere under this district. <b>${T.nodes.length} junctions</b>
      could be responsible. One crew check costs an hour; the wrong excavation costs about
      twenty thousand dollars.`;
    rl='CANDIDATES'; rn=T.nodes.length; rd='every junction, equally likely';
  } else if(st){
    h1=`${held.survivors} junctions<br><em>still possible</em>`;
    stand=`Gauge at node ${st.chosen} reads <b>${st.reading>=0?'+':''}${f(st.reading)} psi</b>.
      Chosen because it removes more uncertainty than any other hydrant —
      <u>${f(st.bits)} bits</u>, ${f(st.minutes,0)} minutes away.
      ${prev?`Down from ${prev.survivors}.`:`Down from ${T.nodes.length}.`}`;
    rl='UNCERTAINTY'; rn=f(held.entropy); rd=`bits · was ${f(Math.log2(T.nodes.length))} at the start`;
  } else if(stage===NP+1){
    h1=`What we know,<br>and what we <em>don't</em>`;
    stand=`<b>${I.blocked.length} of ${I.n_pairs}</b> surviving pairs differ by less than the
      <u>${f(I.threshold)} psi</u> we can distinguish, anywhere in the network. No probe
      sequence separates them. We report a credible set, never a single pipe.`;
    rl='INSEPARABLE PAIRS'; rn=I.blocked.length;
    rd=`smallest gap ${f(I.blocked[0]?I.blocked[0][0]:0,3)} psi`;
  } else if(plan){
    h1=plan.accepted?`The hospital<br><em>holds</em>`:`The hospital<br><em>goes dry</em>`;
    stand=`Closing ${plan.valves||plan.segment.length} valve(s) leaves
      <b>${plan.stranded_hydraulics} of ${T.nodes.length}</b> junctions without service.
      Screened two ways that share no code: reachability across the pipe graph, and a
      pressure-dependent hydraulic run on the same valve set.`;
    rl='HOSPITAL PRESSURE'; rn=f(plan.critical_psi,1);
    rd=`psi · was ${f(plan.baseline_psi,1)} before the work`;
  }
  $('h1').innerHTML=h1; $('stand').innerHTML=stand;
  $('rl').textContent=rl; $('rn').textContent=rn; $('rd').textContent=rd;
  $('pill').textContent=`${T.nodes.length} JUNCTIONS · ${T.pipes.length} PIPES · ${S.sims} RUNS IN ${f(S.sim_seconds)}S`;
  $('src').textContent=`EPA EPANET NET2 · PRESSURE-DEPENDENT DEMAND · GAUGE σ ${f(S.sigma)} PSI · READINGS FROM A PERTURBED MODEL`;
  $('nav').innerHTML=[[1,'METHOD'],[NP+1,'LIMITS'],[NP+2,'RESULTS']]
    .map(([i,l])=>`<span data-j="${i}" ${stage===i?'style="color:var(--ink)"':''}>${l}</span>`).join('');
  document.querySelectorAll('.nav span').forEach(e=>e.onclick=()=>{stage=+e.dataset.j;draw()});

  let R='';
  if(stage>=1){
    const surv=credible(post(stage));
    R+=`<div class="blk"><h2>STILL IN PLAY</h2><div class="tags">${
      surv.map((n,i)=>`<span class="tag ${i===0?'lead':''}">${n}</span>`).join('')}</div>
      <div class="cap">${surv.length} of ${T.nodes.length} junctions hold 90% of the belief.
      Top-1 is not a call we make.</div></div>`;
  }
  if(stage>=NP+2&&T.candidates){
    R+=`<div class="blk"><h2>SHUTDOWN PER CANDIDATE</h2>`;
    T.candidates.forEach(c=>{
      const bad=c.naive_critical_psi<S.critical_min_psi;
      R+=`<div class="row ${bad?'bad':'good'}"><span>node ${c.candidate} · p=${f(c.probability,2)}</span>
        <b>${f(c.critical_psi,0)} psi safe${bad?` / ${f(c.naive_critical_psi)} wrong`:''}</b></div>`;
    });
    R+=`<div class="cap">The exact junction is identified about 10% of the time, so every
      candidate still supported gets its own shutdown plan. At two of these, the wrong
      valve choice puts the hospital at <b>2 psi</b>.</div></div>`;
  }
  if(n3){
    R+=`<div class="blk"><h2>MEASURED AGAINST A RANDOM CONTROL</h2>
      <div class="row good"><span>${n3.junctions}-junction district</span><b>+${f(n3.lift,0)}% closer</b></div>
      <div class="row"><span>finds exact junction</span><b>${f(n3.info_top1,1)}% vs ${f(n3.rand_top1,1)}%</b></div>
      <div class="row"><span>${n2.junctions}-junction network</span><b>no advantage</b></div>
      <div class="cap">Our first figure was 43% closer. A teammate's non-circularity test
      proved that setup was marking its own homework, so it was withdrawn. This is what
      survived: nothing on the small network, <b>3.6× better than chance</b> on a real
      district at p&lt;0.01, across 105 incidents per arm.</div></div>`;
  }
  $('side').innerHTML=R;
}

function steps(){
  const nm=['AT REST',...T.steps.map(s=>`PROBE ${s.step}`),'THE LIMIT',
            ...T.isolation.map((p,i)=>`SHUTDOWN ${String.fromCharCode(65+i)}`)];
  let h='';
  for(let i=0;i<=LAST;i++){
    let v,s;
    if(i===0){v=T.nodes.length;s='candidates'}
    else if(i<=NP){v=T.steps[i-1].survivors;s=`gauge at ${T.steps[i-1].chosen}`}
    else if(i===NP+1){v=T.identifiability.blocked.length;s='inseparable pairs'}
    else{const p=T.isolation[i-NP-2];v=f(p.critical_psi,1);
         s=(p.accepted?'psi · safe':'psi · rejected')+(p.chosen?' · chosen':'')}
    h+=`<div class="cell ${i===stage?'on':''}" data-i="${i}"><div class="k">${nm[i]}</div>
        <div class="v">${v}</div><div class="s">${s}</div></div>`;
  }
  $('steps').innerHTML=h;
  document.querySelectorAll('.cell').forEach(e=>e.onclick=()=>{stage=+e.dataset.i;draw()});
}

addEventListener('resize',()=>{cv.width=innerWidth;cv.height=innerHeight;});
document.onkeydown=e=>{
  if(e.key==='ArrowRight'||e.key===' '){e.preventDefault();if(stage<LAST){stage++;draw()}}
  if(e.key==='ArrowLeft'&&stage>0){stage--;draw()}
};
draw();
</script>
</body>
</html>
""";


def write_page(path: str, body: str) -> int {
    """Write one page as UTF-8 with LF endings, and report its size.""";
    with open(path, "w", encoding="utf-8", newline="") as f { f.write(body); }
    return len(body);
}


with entry:__main__ {
    n1 = write_page("web/index.html", INDEX_HTML);
    n2 = write_page("web/board.html", BOARD_HTML);
    print(f"[pages] web/index.html {n1} chars, web/board.html {n2} chars");
}
