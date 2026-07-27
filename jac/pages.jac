"""PipeTrace - the board pages, emitted from Jac.

The incident board and the landing shell used to sit in the tree as loose HTML that
nothing owned. They live here now: this module holds them and writes them out, so the
page that ships is the page this code emits. main.jac still reads web/board.html as
the template for standalone.html, and this is where that template comes from.

    jac run jac/pages.jac      ->  web/index.html, board.html, dashboard.html

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
      <a href="board.html">SHUTDOWN PLAN</a>
      <a href="dashboard.html" style="color:var(--mint)">LIVE BOARD</a>
    </div>
  </nav>

  <div class="hero">
    <span class="pill"><s></s>35 JUNCTIONS · 40 PIPES · 36 HYDRAULIC RUNS IN 0.23S</span>
    <h1>Find the leak<br>without <em>guessing</em></h1>
    <p>Bayesian leak localisation over live pressure gauges. Rivus reports a credible set
       and the bits it is still missing — never a single pipe it cannot prove.</p>
    <a class="cta" href="dashboard.html">[ RUN A DIAGNOSIS ]</a>
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
    const a=Math.sin(u*9.4+t*1.3+Math.cos(v*5.6+t*.7)*1.5);
    const b=Math.sin(u*4.6-t*.9+v*8.2);
    // Ridges never clip to nothing: a trough still emits a faint dot, so the field
    // reads as water under low light instead of going to black between crests.
    const n=a*.65+b*.35, band=.34+.66*Math.max(0,n);
    const fall=(.5+.5*Math.pow(1-v,1.15))*Math.min(1,u*1.1+.5);
    const r=band*fall*3.2;
    if(r>.14){
      const k=Math.min(1,band*fall*1.5);
      cx.fillStyle=`rgba(${Math.round(62+120*k)},${Math.round(127+110*k)},${Math.round(184+60*k)},${(.11+k*.5).toFixed(3)})`;
      cx.beginPath();cx.arc(x,y,r,0,6.283);cx.fill();
    }
  }
  requestAnimationFrame(frame);
}
frame();   // ambient, encodes nothing: runs even when the system asks for less motion
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

  .flow{animation:flow linear infinite}
  @keyframes flow{to{stroke-dashoffset:-200}}
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
swell();   // ambient, encodes nothing: runs even when the system asks for less motion

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


glob DASHBOARD_HTML: str = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Rivus — live diagnosis</title>
<script src="replay.js"></script>
<style>
  :root{
    --ground:#00070F; --panel:rgba(8,22,31,.35); --well:rgba(2,10,17,.35);
    --edge:rgba(255,255,255,.20); --rule:rgba(255,255,255,.08);
    --ink:#E8F4F8; --ink2:rgba(255,255,255,.70); --ink3:rgba(255,255,255,.45);
    --belief:#2DD4BF; --belief-deep:#22A5C4; --foam:#BFE9FF; --cost:#E8A33D;
    --mono:"SF Mono",ui-monospace,Menlo,Consolas,monospace;
    --disp:"Iowan Old Style",Georgia,"Times New Roman",serif;
    --ease:cubic-bezier(.32,.72,0,1);
  }
  *{box-sizing:border-box;margin:0;padding:0}
  html,body{height:100%;overflow:hidden}
  body{background:var(--ground);color:var(--ink);font-family:var(--mono);font-size:13px;
       -webkit-font-smoothing:antialiased;font-feature-settings:"tnum"}

  /* Atmosphere layers the panels refract, none of them carrying data: the ambient
     orbs, the halftone swell the landing page uses, and the particle field over it. */
  /* Orbs and grain are the echoes project's background, structure kept as it was
     there, two ellipses and a fractal-noise overlay, with its gold swapped for the
     water blue this system already uses. */
  #orbs{position:fixed;inset:0;pointer-events:none;z-index:0;
        background:
          radial-gradient(ellipse 70% 40% at 50% 0%, rgba(62,127,184,.40) 0%, transparent 60%),
          radial-gradient(ellipse 50% 30% at 100% 100%, rgba(62,127,184,.28) 0%, transparent 50%)}
  #swell{position:fixed;inset:0;pointer-events:none;z-index:1;opacity:.55}
  #field{position:fixed;inset:0;pointer-events:none;z-index:2}
  #scrim{position:fixed;inset:0;background:rgba(0,0,0,.10);pointer-events:none;z-index:3}
  #grain{position:fixed;inset:0;pointer-events:none;z-index:9999;opacity:.35;
         background-image:url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.85' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)' opacity='0.035'/%3E%3C/svg%3E")}

  #page{position:relative;z-index:3;height:100svh;display:flex;flex-direction:column;
        gap:12px;padding:16px}

  .panel{background:var(--panel);border:1px solid var(--edge);border-radius:16px;
         backdrop-filter:blur(12px);-webkit-backdrop-filter:blur(12px);
         box-shadow:0 10px 40px -16px rgba(0,0,0,.7)}

  .lbl{font-size:10px;text-transform:uppercase;letter-spacing:.16em;color:var(--ink3)}
  .num{font-variant-numeric:tabular-nums}

  /* command bar */
  .bar{display:flex;align-items:center;gap:12px;padding:10px 14px;flex-wrap:wrap}
  .brand{display:flex;align-items:center;gap:9px;text-decoration:none;color:var(--ink)}
  .glyph{width:17px;height:17px;position:relative}
  .glyph i{position:absolute;width:7px;height:7px;background:var(--belief)}
  .glyph i:nth-child(1){left:0;top:10px}
  .glyph i:nth-child(2){left:5px;top:5px;opacity:.75}
  .glyph i:nth-child(3){left:10px;top:0;opacity:.5}
  .brand b{font-weight:400;font-size:15px;letter-spacing:.02em}
  .sep{width:1px;height:24px;background:var(--rule)}

  select{background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.13);
         border-radius:8px;height:32px;padding:0 26px 0 10px;color:var(--ink);
         font:inherit;font-size:12px;outline:none;appearance:none;
         background-image:url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='10' height='10' viewBox='0 0 10 10'><path d='M1 3l4 4 4-4' stroke='rgba(255,255,255,0.5)' stroke-width='1.4' fill='none'/></svg>");
         background-repeat:no-repeat;background-position:right 8px center}
  select option{background:#00121A}

  button{font:inherit;color:inherit;background:none;border:none;cursor:pointer}
  .arm{font-size:11px;height:32px;padding:0 10px;border-radius:8px;
       border:1px solid rgba(255,255,255,.10);color:var(--ink3);
       transition:all 200ms var(--ease)}
  .arm:hover{color:var(--ink);background:rgba(255,255,255,.06)}
  .arm:active{transform:scale(.97)}
  .arm.on{border-color:rgba(45,212,191,.5);color:var(--belief);background:rgba(45,212,191,.10)}
  .arm .only{color:rgba(255,255,255,.25);margin-left:6px}

  .navlink{font-size:10px;text-transform:uppercase;letter-spacing:.12em;
           color:var(--ink3);text-decoration:none;transition:color 150ms var(--ease)}
  .navlink:hover{color:var(--ink)}

  .pips{display:flex;gap:4px;width:132px;flex:none}
  .pips i{height:6px;flex:1;border-radius:99px;background:rgba(255,255,255,.13);
          transition:background 200ms var(--ease)}
  .pips i.on{background:var(--belief)}

  .play{display:flex;align-items:center;gap:8px;font-size:12px;height:36px;padding:0 14px;
        border-radius:8px;border:1px solid rgba(45,212,191,.5);color:var(--belief);
        background:rgba(45,212,191,.10);transition:all 200ms var(--ease)}
  .play:hover{background:rgba(45,212,191,.20)}
  .play:active{transform:scale(.97)}
  .step{height:36px;width:36px;display:grid;place-items:center;border-radius:8px;
        border:1px solid rgba(255,255,255,.13);color:var(--ink2);transition:all 200ms var(--ease)}
  .step:hover{color:var(--ink);background:rgba(255,255,255,.06)}
  .step:active{transform:scale(.97)}

  /* body split */
  .split{flex:1;min-height:0;display:grid;grid-template-columns:70% 14px minmax(0,1fr);gap:0}
  .divider{cursor:col-resize;position:relative;touch-action:none;outline:none}
  .divider s{position:absolute;inset:0 auto;left:50%;transform:translateX(-50%);width:1px;
             background:rgba(255,255,255,.15);text-decoration:none}
  .divider:hover s,.divider:focus s{background:rgba(255,255,255,.40)}
  .divider b{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);
             width:3px;height:48px;border-radius:99px;background:rgba(255,255,255,.25)}
  .divider:hover b{background:rgba(255,255,255,.55)}
  .divider.drag s,.divider.drag b{background:var(--belief)}

  .map{padding:16px;display:flex;flex-direction:column;min-height:0}
  .maphead{display:flex;align-items:baseline;justify-content:space-between;gap:12px;flex:none}
  h1{font-family:var(--disp);font-weight:400;font-size:clamp(20px,2vw,26px);line-height:1.15}
  h1 i{font-style:italic}
  .toggle{height:28px;padding:0 9px;display:flex;align-items:center;gap:6px;border-radius:6px;
          border:1px solid rgba(255,255,255,.15);color:var(--ink3);font-size:9px;
          text-transform:uppercase;letter-spacing:.14em;transition:all 200ms var(--ease)}
  .toggle:hover{color:var(--ink);background:rgba(255,255,255,.07)}
  .toggle.off{border-color:rgba(45,212,191,.5);color:var(--belief);background:rgba(45,212,191,.10)}

  .well{flex:1;min-height:0;margin-top:8px;border-radius:12px;overflow:hidden;
        border:1px solid rgba(255,255,255,.10);background:var(--well)}
  .well svg{width:100%;height:100%;display:block}

  .cset{flex:none;margin-top:12px;display:flex;align-items:flex-start;gap:12px}
  .chips{display:flex;flex-wrap:wrap;gap:4px;align-content:flex-start}
  .chip{font-size:11px;padding:2px 6px;border-radius:4px;border:1px solid rgba(232,163,61,.35);
        color:var(--ink2);transition:all 160ms var(--ease);font-variant-numeric:tabular-nums}
  .chip.hot{border-color:rgba(191,233,255,.7);color:var(--foam);background:rgba(191,233,255,.10)}
  .big .chip{font-size:14px;padding:4px 10px}

  .legend{flex:none;display:flex;flex-wrap:wrap;gap:6px 20px;margin-top:10px;
          font-size:10px;color:var(--ink3)}
  .legend span{display:flex;align-items:center;gap:6px}
  .sw{width:10px;height:10px;border-radius:99px}

  /* right rail */
  .rail{min-height:0;display:flex;flex-direction:column;gap:12px}
  .duo{display:grid;grid-template-columns:1fr 1fr;gap:12px}
  .cell{padding:14px}
  .cell .v{font-size:26px;line-height:1.1;margin-top:2px}
  .cell .v s{font-size:12px;color:var(--ink3);text-decoration:none;margin-left:6px}
  .cost{color:var(--cost)}
  .foot{font-size:10px;color:var(--ink3);margin-top:2px}
  .bars{margin-top:6px;height:24px;display:flex;align-items:flex-end;gap:4px}
  .bars i{flex:1;border-radius:2px;background:rgba(255,255,255,.10);transition:background 220ms var(--ease)}
  .bars i.on{background:var(--cost)}

  .cand{display:flex;align-items:center;gap:10px;padding:2px 8px;border-radius:8px;
        transition:background 160ms var(--ease)}
  .cand.hot{background:rgba(255,255,255,.07)}
  .cand .id{width:24px;font-size:11px;color:var(--ink3)}
  .cand .track{position:relative;flex:1;height:6px;border-radius:99px;background:rgba(255,255,255,.08);overflow:hidden}
  .cand .fill{height:100%;width:100%;border-radius:99px;transform-origin:left;
              background:linear-gradient(90deg,var(--belief-deep),var(--belief));
              transition:transform 260ms var(--ease)}
  .cand .tick{position:absolute;top:0;bottom:0;width:1px;background:rgba(255,255,255,.35)}
  .cand .pct{width:46px;text-align:right;font-size:11px;color:var(--ink2)}
  .cand .in{width:6px;height:6px;border-radius:99px;background:var(--foam)}

  .log{flex:1;min-height:0;overflow-y:auto;display:flex;flex-direction:column;gap:3px}
  .log::-webkit-scrollbar{width:6px}
  .log::-webkit-scrollbar-thumb{background:rgba(255,255,255,.12);border-radius:99px}
  .log .row{display:flex;align-items:center;gap:8px;font-size:11px}
  .log .row .i{width:14px;color:var(--ink3)}
  .log .row .g{color:var(--ink2)}
  .log .row .p{color:var(--ink3)}
  .log .row .b{margin-left:auto;color:var(--belief)}
  .last{margin-top:10px;padding-top:10px;border-top:1px solid var(--rule);flex:none}
  .trio{display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px;margin-top:6px}
  .trio .v{font-size:14px;color:var(--ink2)}
  .trio .k{font-size:10px;color:var(--ink3)}

  /* bottom strip */
  .strip{flex:none;display:flex;align-items:flex-start;gap:24px;padding:16px 20px}
  .badge{font-size:9px;text-transform:uppercase;letter-spacing:.16em;padding:4px 8px;
         border-radius:4px;border:1px solid rgba(45,212,191,.35);color:rgba(45,212,191,.9);flex:none}
  .grid{display:grid;grid-template-columns:repeat(5,1fr);gap:8px;margin-top:6px}
  .card{text-align:left;border-radius:8px;padding:8px 12px;border:1px solid rgba(255,255,255,.07);
        transition:all 180ms var(--ease)}
  .card:hover{border-color:rgba(255,255,255,.20)}
  .card.on{border-color:rgba(45,212,191,.45);background:rgba(45,212,191,.07)}
  .card.chance{border-style:dashed;border-color:rgba(255,255,255,.10);cursor:default}
  .card .n{font-size:10px;color:var(--ink3);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  .card.on .n{color:var(--belief)}
  .card .v{font-size:18px;margin-top:2px;color:var(--ink2)}
  .card.on .v{color:var(--belief)}
  .card .p{font-size:10px;color:var(--cost);margin-left:6px}
  .card.chance .v,.card.chance .n{color:var(--ink3)}
  .card.chance .p{color:var(--ink3)}
  .note{font-size:10px;color:var(--ink3);margin-top:10px}

  /* Water motion. The duration is set per pipe from its flow, so a main visibly
     moves faster than a branch. Without the name here the dashes never ran. */
  .flow{animation-name:flow;animation-timing-function:linear;animation-iteration-count:infinite}
  /* A probe reads as belief moving, not as a cut. */
  #plot circle.heat{transition:r 220ms var(--ease),fill 220ms var(--ease)}
  #plot circle.ring{transition:r 220ms var(--ease),opacity 220ms var(--ease)}

  /* The ambient layers keep moving even when the system asks for less motion: they
     are the page's weather, they encode nothing, and the site they replace ran them
     unconditionally. The data-carrying motion below does respect the setting. */
  /* Only the ripple stays gated: it pulses, and that is the motion a reduced-motion
     preference is actually about. The dashes drift linearly and the belief update is
     a 220ms fade, so both keep running. */
  @media (prefers-reduced-motion: reduce){
    .ripple{animation:none !important}
  }
  @keyframes flow{to{stroke-dashoffset:-16}}
  @keyframes ripple{0%{opacity:.5;transform:scale(1)}100%{opacity:0;transform:scale(2.8)}}
</style>
</head>
<body>
<div id="orbs"></div>
<canvas id="swell"></canvas>
<canvas id="field"></canvas>
<div id="scrim"></div>
<div id="grain"></div>

<div id="page">
  <header class="panel bar">
    <a class="brand" href="index.html"><span class="glyph"><i></i><i></i><i></i></span><b>Rivus</b></a>
    <span class="sep"></span>
    <select id="incident"></select>
    <span id="arms" style="display:flex;gap:6px;flex-wrap:wrap"></span>
    <span style="margin-left:auto;display:flex;align-items:center;gap:10px">
      <a class="navlink" href="method.html">Method</a>
      <a class="navlink" href="results.html">Results</a>
      <a class="navlink" href="limits.html">Limits</a>
      <span class="pips" id="pips"></span>
      <button class="play" id="play"></button>
      <button class="step" id="stepfwd" title="Step forward">&#9654;&#124;</button>
    </span>
  </header>

  <div class="split" id="split">
    <section class="panel map" id="mappanel">
      <div class="maphead">
        <h1>What we know, and what we <i>don't</i></h1>
        <button class="toggle" id="toggle"></button>
      </div>
      <div class="well" id="well"><svg id="plot" preserveAspectRatio="xMidYMid meet"></svg></div>
      <div class="cset" id="cset"></div>
      <div class="legend">
        <span><i class="sw" style="background:var(--belief)"></i>Belief mass</span>
        <span><i class="sw" style="border:1px solid rgba(45,212,191,.6)"></i>Gauge</span>
        <span><i class="sw" style="border:1px dashed rgba(191,233,255,.7)"></i>In credible set</span>
        <span><i class="sw" style="border:2px solid var(--cost)"></i>Probed now</span>
        <span><i class="sw" style="border:1px solid #8FA6B4;border-radius:0"></i>Source</span>
      </div>
    </section>

    <div class="divider" id="divider" tabindex="0" title="Drag to resize, double-click to reset"><s></s><b></b></div>

    <aside class="rail">
      <div class="duo">
        <div class="panel cell">
          <div class="lbl">Uncertainty</div>
          <div class="v num" id="bits"></div>
          <svg id="spark" viewBox="0 0 120 32" preserveAspectRatio="none" style="width:100%;height:26px;overflow:visible"></svg>
          <div class="foot" id="bitsfoot"></div>
        </div>
        <div class="panel cell">
          <div class="lbl">Dispatches</div>
          <div class="v num cost" id="disp"></div>
          <div class="bars" id="dispbars"></div>
          <div class="foot" id="dispfoot"></div>
        </div>
      </div>

      <div class="panel cell">
        <div class="lbl" style="margin-bottom:10px">Leading candidates</div>
        <div id="cands"></div>
        <div class="foot" style="margin-top:10px;padding-top:10px;border-top:1px solid var(--rule)">
          Top-1 is not a call we make.
        </div>
      </div>

      <div class="panel cell" style="flex:1;min-height:0;display:flex;flex-direction:column">
        <div class="lbl" style="margin-bottom:10px">Probe log</div>
        <div class="log" id="log"></div>
        <div class="last">
          <div class="lbl">Last probe</div>
          <div class="trio">
            <div><div class="v num" id="lpg"></div><div class="k">Read</div></div>
            <div><div class="v num" id="lpp"></div><div class="k">psi</div></div>
            <div><div class="v num" id="lpb" style="color:var(--belief)"></div><div class="k">Bits expected</div></div>
          </div>
          <div class="foot" id="noise" style="margin-top:8px"></div>
        </div>
      </div>
    </aside>
  </div>

  <footer class="panel strip">
    <div style="flex:none">
      <div class="lbl">Network</div>
      <div class="num" style="font-size:11px;color:var(--ink2);margin-top:4px" id="net"></div>
      <div class="num foot" id="netsub"></div>
    </div>
    <span class="badge" id="fixture" hidden>Fixture data</span>
    <div style="width:1px;height:56px;background:var(--rule);flex:none"></div>
    <div style="flex:1;min-width:0">
      <div style="display:flex;align-items:baseline;justify-content:space-between;gap:12px">
        <div class="lbl" id="measured"></div>
        <div class="foot" id="axes"></div>
      </div>
      <div class="grid" id="cards"></div>
      <p class="note" id="note"></p>
    </div>
  </footer>
</div>

<script>
/* ------------------------------------------------------------------ data ---- */
/* replay.js sets window.REPLAY so the page opens over file:// with no server.
   The fetch is the fallback for when it is served instead. */
const boot = window.REPLAY
  ? Promise.resolve(window.REPLAY)
  : fetch("replay.json").then(r => r.json());

const $ = id => document.getElementById(id);
const fx = (v, n) => Number(v).toFixed(n);
const sentence = s => s.charAt(0).toUpperCase() + s.slice(1);
const EASE = "cubic-bezier(.32,.72,0,1)";
const FULL_HEAT = 0.5;      /* belief that earns a fully saturated node */
const VIEW = 1000, PAD = 0.07;

let D, plotKey = "", incidentIdx = 0, armKey = "adaptive", step = 0, playing = false,
    hover = null, showMap = true, timer = null, splitPct = 70;

/* ------------------------------------------------------- halftone swell ---- */
/* The landing page's dot field, carried through as living atmosphere: stacked sine
   ridges sampled on a grid, the same shape family as the hero artwork. */
(function swellField(){
  const cv = $("swell"), cx = cv.getContext("2d");
  const t0 = performance.now();
  (function swell(){
    requestAnimationFrame(swell);
    const w = cv.width = innerWidth, h = cv.height = innerHeight;
    const t = (performance.now() - t0) / 9000, gap = 13;
    cx.clearRect(0, 0, w, h);
    for (let y = 0; y < h; y += gap) {
      for (let x = 0; x < w; x += gap) {
        const u = x / w, v = y / h;
        const a = Math.sin(u * 5.2 + t * 1.3 + Math.cos(v * 3.1 + t * 0.7) * 1.5);
        const b = Math.sin(u * 2.4 - t * 0.9 + v * 4.6);
        const band = Math.max(0, a * 0.65 + b * 0.35);
        const fall = Math.pow(1 - v, 1.5) * Math.min(1, u * 1.6 + 0.15);
        const r = band * fall * 3.1;
        if (r > 0.22) {
          const wash = Math.min(1, band * fall * 1.5);
          cx.fillStyle = "rgba(" + Math.round(62 + 180 * wash) + "," + Math.round(127 + 120 * wash)
                       + "," + Math.round(184 + 66 * wash) + "," + (0.09 + wash * 0.5).toFixed(3) + ")";
          cx.beginPath(); cx.arc(x, y, r, 0, 6.283); cx.fill();
        }
      }
    }
  })();
})();

/* ------------------------------------------------------ particle field ---- */
/* Ported from the Echoes background: same motion and connection lines, in the
   water blues. Decoration only, and it never encodes data. */
(function field(){
  const cv = $("field"), cx = cv.getContext("2d");
  const COLORS = ["#2E6FA8","#3D8FC4","#1E4E78","#6FA8D8","#BFE9FF","#255C86"];
  const N = 120, SPEED = 1.4, SIZE = 2, CONN = 130;
  let mx = innerWidth / 2, my = innerHeight / 2;
  const resize = () => { cv.width = innerWidth; cv.height = innerHeight; };
  resize();
  addEventListener("resize", resize);
  addEventListener("mousemove", e => { mx = e.clientX; my = e.clientY; });
  const P = Array.from({length: N}, () => ({
    x: Math.random() * cv.width, y: Math.random() * cv.height,
    s: Math.random() * SIZE * 1.5 + 0.5,
    bx: (Math.random() * 2 - 1) * SPEED, by: (Math.random() * 2 - 1) * SPEED,
    vx: 0, vy: 0, c: COLORS[Math.floor(Math.random() * COLORS.length)]
  }));
  P.forEach(p => { p.vx = p.bx; p.vy = p.by; });
  (function frame(){
    requestAnimationFrame(frame);
    /* Cleared rather than washed with a translucent fill: the swell sits behind this
       layer and a fill would bury it. */
    cx.clearRect(0, 0, cv.width, cv.height);
    for (const p of P) {
      const dx = p.x - mx, dy = p.y - my, d = Math.hypot(dx, dy);
      if (d < 120 && d > 0) {
        const a = Math.atan2(dy, dx), f = (120 - d) / 12;
        p.vx += Math.cos(a) * f * 0.18; p.vy += Math.sin(a) * f * 0.18;
      }
      const cap = SPEED * 2.5;
      p.vx = Math.max(-cap, Math.min(cap, p.vx)) * 0.97 + p.bx * 0.03;
      p.vy = Math.max(-cap, Math.min(cap, p.vy)) * 0.97 + p.by * 0.03;
      p.x += p.vx; p.y += p.vy;
      if (p.x < 0) p.x = cv.width; if (p.x > cv.width) p.x = 0;
      if (p.y < 0) p.y = cv.height; if (p.y > cv.height) p.y = 0;
      cx.beginPath(); cx.arc(p.x, p.y, p.s, 0, Math.PI * 2);
      cx.fillStyle = p.c; cx.fill();
    }
    cx.lineWidth = 0.5;
    for (let i = 0; i < P.length; i++) {
      const lim = Math.min(P.length, i + 14);
      for (let j = i + 1; j < lim; j++) {
        const d = Math.hypot(P[i].x - P[j].x, P[i].y - P[j].y);
        if (d < CONN) {
          cx.strokeStyle = "rgba(61,124,148," + ((1 - d / CONN) * 0.17).toFixed(3) + ")";
          cx.beginPath(); cx.moveTo(P[i].x, P[i].y); cx.lineTo(P[j].x, P[j].y); cx.stroke();
        }
      }
    }
  })();
})();

/* ------------------------------------------------------------ geometry ---- */
let POS = null, VW = 0, VH = 0;
function project(){
  const all = D.network.junctions.concat(D.network.sources);
  const xs = all.map(n => n.x), ys = all.map(n => n.y);
  const minX = Math.min(...xs), maxX = Math.max(...xs);
  const minY = Math.min(...ys), maxY = Math.max(...ys);
  /* EPANET is Y-up over arbitrary ranges: normalise into the viewBox and flip Y. */
  const spanX = (maxX - minX) || 1, spanY = (maxY - minY) || 1;
  VW = VIEW; VH = VIEW * (spanY / spanX);
  const scale = (VW * (1 - 2 * PAD)) / spanX;
  POS = new Map();
  for (const n of all) {
    POS.set(n.id, { x: VW * PAD + (n.x - minX) * scale, y: VH * PAD + (maxY - n.y) * scale });
  }
}

/* --------------------------------------------------------------- render ---- */
function incident(){ return D.incidents[incidentIdx]; }
function arm(){ return incident().arms[armKey]; }
function steps(){ return arm() ? arm().steps : []; }
function current(){ return steps()[Math.min(step, steps().length - 1)]; }
function finished(){ return step >= steps().length - 1; }

function replayableArms(){
  const label = {randomControl:"random control", maxInfoGain:"max information gain",
                 adaptive:"adaptive stopping", allGauges:"all gauges"};
  return Object.keys(incident().arms).map(k => {
    const m = D.summary.arms.find(a => a.key === k);
    return { key: k, name: m ? m.name : (label[k] || k), measured: !!m };
  });
}

function drawPlot(){
  if (!showMap) return;
  const key = incidentIdx + "|" + armKey;
  if (key !== plotKey) { buildPlot(); plotKey = key; }
  updatePlot();
}

/* Built once per run. Every mark a junction can carry exists from the start and is
   only ever re-valued, because a node replaced on each step cannot transition. */
function buildPlot(){
  const net = D.network, gauges = new Set(net.gauges);
  const maxFlow = Math.max(...net.pipes.map(p => Math.abs(p.flow)), 1);
  let s = '<defs><radialGradient id="peak">' +
          '<stop offset="0%" stop-color="var(--belief)" stop-opacity=".35"/>' +
          '<stop offset="100%" stop-color="var(--belief)" stop-opacity="0"/></radialGradient></defs>';
  s += '<circle id="peakglow" r="110" fill="url(#peak)" opacity="0"/>';

  let d = "";
  for (const p of net.pipes) {
    const a = POS.get(p.from), b = POS.get(p.to);
    if (!a || !b) continue;
    d += `M${a.x.toFixed(1)} ${a.y.toFixed(1)}L${b.x.toFixed(1)} ${b.y.toFixed(1)}`;
  }
  s += `<path d="${d}" stroke="#25505F" stroke-width="2" fill="none"/>`;

  for (const p of net.pipes) {
    const a = POS.get(p.from), b = POS.get(p.to);
    if (!a || !b) continue;
    const dur = 6 - (Math.abs(p.flow) / maxFlow) * 5.2;
    s += `<line class="flow" x1="${a.x}" y1="${a.y}" x2="${b.x}" y2="${b.y}" stroke="#3D7C94" ` +
         `stroke-width="2" stroke-dasharray="6 10" style="animation-duration:${dur.toFixed(2)}s"/>`;
  }

  for (const src of net.sources) {
    const p = POS.get(src.id);
    s += `<rect x="${p.x - 6}" y="${p.y - 6}" width="12" height="12" fill="none" stroke="#8FA6B4" stroke-width="1.5"/>` +
         `<text x="${p.x + 11}" y="${p.y + 4}" fill="#8FA6B4" font-size="13" font-family="monospace">${src.id}</text>`;
  }

  for (const j of net.junctions) {
    const p = POS.get(j.id);
    s += `<g data-j="${j.id}" style="cursor:pointer">` +
         `<circle id="rp${j.id}" class="ripple" cx="${p.x}" cy="${p.y}" r="5" fill="none" ` +
           `stroke="var(--belief)" stroke-width="1.5" opacity="0" style="display:none;` +
           `animation:ripple 2.4s ${EASE} infinite;animation-delay:${((+j.id % 7) * 0.3).toFixed(1)}s;` +
           `transform-origin:${p.x}px ${p.y}px"/>` +
         (gauges.has(j.id)
           ? `<circle id="gr${j.id}" class="ring" cx="${p.x}" cy="${p.y}" r="10" fill="none" stroke="var(--belief)" stroke-width="1" opacity=".45"/>`
           : "") +
         `<circle id="sr${j.id}" class="ring" cx="${p.x}" cy="${p.y}" r="7.5" fill="none" stroke="var(--foam)" ` +
           `stroke-width="1" stroke-dasharray="3 3" opacity="0"/>` +
         `<circle id="h${j.id}" class="heat" cx="${p.x}" cy="${p.y}" r="5" fill="#4A7286"/>` +
         `<circle id="pr${j.id}" class="ring" cx="${p.x}" cy="${p.y}" r="15" fill="none" stroke="var(--cost)" stroke-width="2" opacity="0"/>` +
         `<circle cx="${p.x}" cy="${p.y}" r="18" fill="transparent"/>` +
         `</g>`;
  }

  s += '<g id="tip" pointer-events="none"></g><g id="truth" pointer-events="none"></g>';
  const plot = $("plot");
  plot.setAttribute("viewBox", `0 0 ${VW} ${VH}`);
  plot.innerHTML = s;
}

/* Re-values the marks for the current step. Radius and fill carry a CSS transition,
   so the belief update is visible as motion. */
function updatePlot(){
  const c = current(), net = D.network;
  const gauges = new Set(net.gauges), inSet = new Set(c.credibleSet);
  const chance = 1 / net.junctions.length;
  const heat = p => Math.max(0, Math.min(1, (p - chance) / (FULL_HEAT - chance)));
  const ranked = Object.entries(c.posterior).sort((a, b) => b[1] - a[1]);
  const maxP = ranked[0][1];

  const glow = $("peakglow"), lead = POS.get(ranked[0][0]);
  if (lead && maxP > chance * 2) {
    glow.setAttribute("cx", lead.x); glow.setAttribute("cy", lead.y);
    glow.setAttribute("opacity", heat(maxP).toFixed(3));
  } else { glow.setAttribute("opacity", "0"); }

  for (const j of net.junctions) {
    const prob = c.posterior[j.id] || 0, t = heat(prob), r = 5 + t * 9;
    const h = document.getElementById("h" + j.id);
    h.setAttribute("r", r.toFixed(2));
    h.setAttribute("fill", `rgb(${Math.round(74 - t * 29)},${Math.round(114 + t * 98)},${Math.round(134 + t * 57)})`);

    const rp = document.getElementById("rp" + j.id);
    rp.style.display = t > 0.15 ? "" : "none";
    rp.setAttribute("r", r.toFixed(2));

    if (gauges.has(j.id)) document.getElementById("gr" + j.id).setAttribute("r", (r + 5).toFixed(2));

    const sr = document.getElementById("sr" + j.id);
    sr.setAttribute("r", (r + 2.5).toFixed(2));
    sr.setAttribute("opacity", inSet.has(j.id) ? "0.7" : "0");

    const pr = document.getElementById("pr" + j.id);
    pr.setAttribute("r", (r + 10).toFixed(2));
    pr.setAttribute("opacity", c.probeGauge === j.id ? "1" : "0");
  }

  const tip = $("tip");
  if (hover && POS.get(hover) && c.posterior[hover] !== undefined) {
    const p = POS.get(hover);
    tip.innerHTML =
      `<rect x="${p.x + 14}" y="${p.y - 30}" width="126" height="38" rx="6" fill="#00121A" stroke="rgba(255,255,255,.2)"/>` +
      `<text x="${p.x + 22}" y="${p.y - 15}" fill="white" font-size="13" font-family="monospace">Junction ${hover}</text>` +
      `<text x="${p.x + 22}" y="${p.y + 1}" fill="var(--belief)" font-size="13" font-family="monospace">` +
      `${(c.posterior[hover] * 100).toFixed(1)}% belief</text>`;
  } else { tip.innerHTML = ""; }

  const truth = $("truth"), tp = POS.get(incident().trueLeakJunction);
  if (finished() && tp) {
    truth.innerHTML =
      `<rect x="${tp.x - 11}" y="${tp.y - 11}" width="22" height="22" fill="none" stroke="#63798C" stroke-width="1.5"/>` +
      `<text x="${tp.x + 16}" y="${tp.y - 12}" fill="#63798C" font-size="12" font-family="monospace">Ground truth (evaluation only)</text>`;
  } else { truth.innerHTML = ""; }
}

function render(){
  const c = current(), a = arm(), net = D.network, sum = D.summary;
  const chance = 1 / net.junctions.length;
  const ranked = Object.entries(c.posterior).sort((x, y) => y[1] - x[1]);
  const maxP = ranked[0][1];
  const inSet = new Set(c.credibleSet);
  const prior = steps()[0].entropyBits;
  const spent = steps().slice(0, step + 1).filter(s => s.probeGauge).length;
  const saved = 3 - a.probesUsed;

  $("incident").innerHTML = D.incidents
    .map((i, k) => `<option value="${k}"${k === incidentIdx ? " selected" : ""}>${i.id} · ${i.leakGpm} gpm</option>`).join("");

  $("arms").innerHTML = replayableArms().map(x =>
    `<button class="arm${x.key === armKey ? " on" : ""}" data-arm="${x.key}">${sentence(x.name)}` +
    `${x.measured ? "" : '<span class="only">· replay only</span>'}</button>`).join("");

  $("pips").innerHTML = steps().map((_, i) => `<i class="${i <= step ? "on" : ""}"></i>`).join("");
  $("play").innerHTML = playing ? "&#10074;&#10074; Pause" : (finished() ? "&#8635; Replay" : "&#9654; Play");
  $("toggle").textContent = showMap ? "Map on" : "Map off";
  $("toggle").className = "toggle" + (showMap ? "" : " off");
  $("mappanel").querySelector(".well").hidden = !showMap;

  /* uncertainty */
  $("bits").innerHTML = fx(c.entropyBits, 2) + "<s>bits</s>";
  $("bitsfoot").textContent = "−" + fx(prior - c.entropyBits, 2) + " from " + fx(prior, 2);
  const hist = steps().slice(0, step + 1).map(s => s.entropyBits);
  if (hist.length > 1) {
    const pts = hist.map((v, i) => `${(i / (hist.length - 1) * 120).toFixed(1)},${(32 - v / prior * 32).toFixed(1)}`);
    $("spark").innerHTML =
      '<line x1="0" y1="0" x2="120" y2="0" stroke="rgba(255,255,255,.18)" stroke-width="1" stroke-dasharray="3 3"/>' +
      `<polyline points="${pts.join(" ")}" fill="none" stroke="var(--belief)" stroke-width="2" vector-effect="non-scaling-stroke"/>` +
      `<circle cx="120" cy="${(32 - hist[hist.length - 1] / prior * 32).toFixed(1)}" r="3" fill="var(--belief)"/>`;
  } else { $("spark").innerHTML = ""; }

  /* dispatches */
  $("disp").innerHTML = spent + `<s>of ${a.probesUsed}</s>`;
  $("dispbars").innerHTML = Array.from({length: Math.max(a.probesUsed, 3)}, (_, i) =>
    `<i class="${i < spent ? "on" : ""}" style="height:${i < a.probesUsed ? 100 : 34}%"></i>`).join("");
  $("dispfoot").textContent = saved > 0 ? saved + " fewer than the fixed arms" : "Crews sent to a street";

  /* candidates */
  const scale = Math.max(maxP, chance * 4);
  $("cands").innerHTML = ranked.slice(0, 6).map(([id, p]) =>
    `<div class="cand${hover === id ? " hot" : ""}" data-j="${id}">` +
    `<span class="id num">${id}</span>` +
    `<span class="track"><span class="fill" style="transform:scaleX(${(p / scale).toFixed(4)})"></span>` +
    `<span class="tick" style="left:${(chance / scale * 100).toFixed(2)}%"></span></span>` +
    `<span class="pct num">${(p * 100).toFixed(1)}%</span>` +
    (inSet.has(id) ? '<span class="in"></span>' : '<span style="width:6px"></span>') + "</div>").join("");

  /* credible set */
  $("cset").className = "cset" + (showMap ? "" : " big");
  $("cset").innerHTML =
    `<div style="flex:none;padding-top:2px"><div class="lbl">Credible set · 90%</div>` +
    `<div class="foot num">${c.credibleSet.length} of ${net.junctions.length} still in play</div></div>` +
    `<div class="chips">` + c.credibleSet.map(id =>
      `<span class="chip${hover === id ? " hot" : ""}" data-j="${id}">${id}</span>`).join("") + `</div>`;

  /* probe log */
  $("log").innerHTML = steps().slice(0, step + 1).map((s, i) => {
    const drop = i > 0 ? steps()[i - 1].entropyBits - s.entropyBits : 0;
    return `<div class="row num"><span class="i">${i}</span>` +
      `<span class="${s.probeGauge ? "g" : "p"}">${s.probeGauge ? "Gauge " + s.probeGauge : "Prior"}</span>` +
      `<span class="p">${s.readingPsi !== null ? fx(s.readingPsi, 1) + " psi" : "n/a"}</span>` +
      `<span class="b">${i === 0 ? fx(s.entropyBits, 2) + "b" : "−" + fx(drop, 2) + "b"}</span></div>`;
  }).join("");
  $("lpg").textContent = c.probeGauge ? "Gauge " + c.probeGauge : "n/a";
  $("lpp").textContent = c.readingPsi !== null ? fx(c.readingPsi, 2) : "n/a";
  $("lpb").textContent = c.eigBits !== null ? fx(c.eigBits, 3) : "n/a";
  $("noise").textContent = "Gauge noise " + sum.noisePsi + " psi";

  /* bottom strip */
  $("net").textContent = `${net.junctions.length} junctions · ${net.pipes.length} pipes · ${net.gauges.length} gauges`;
  $("netsub").textContent = `Leak ${incident().leakGpm} gpm · gauge noise ${sum.noisePsi} psi`;
  $("fixture").hidden = !D.fixture;
  $("measured").textContent = `Measured over ${sum.nIncidents} incidents`;
  $("axes").textContent = `Top-5 accuracy · mean crew dispatches · chance ${sum.chancePct}%`;
  $("cards").innerHTML = sum.arms.map(x =>
    `<button class="card${x.key === armKey ? " on" : ""}" data-arm="${x.key}">` +
    `<div class="n">${sentence(x.name)}</div><div class="v num">${x.top5Pct}%<span class="p">${x.meanProbes}p</span></div></button>`).join("") +
    `<div class="card chance"><div class="n">Chance</div><div class="v num">${sum.chancePct}%<span class="p">n/a</span></div></div>`;
  $("note").textContent = sum.note || "Reported as measured, against a random control on every incident.";

  drawPlot();
}

/* -------------------------------------------------------------- controls ---- */
function stop(){ playing = false; clearTimeout(timer); }
function tick(){
  clearTimeout(timer);
  if (!playing) return;
  if (finished()) { playing = false; render(); return; }
  timer = setTimeout(() => { step++; render(); tick(); }, 1500);
}

document.addEventListener("click", e => {
  const armBtn = e.target.closest("[data-arm]");
  if (armBtn) { armKey = armBtn.dataset.arm; step = 0; stop(); render(); return; }
  if (e.target.closest("#play")) {
    if (finished() && !playing) { step = 0; playing = true; } else { playing = !playing; }
    render(); tick(); return;
  }
  if (e.target.closest("#stepfwd")) { stop(); step = Math.min(step + 1, steps().length - 1); render(); return; }
  if (e.target.closest("#toggle")) { showMap = !showMap; plotKey = ""; render(); return; }
});

document.addEventListener("mouseover", e => {
  const t = e.target.closest("[data-j]");
  const id = t ? t.dataset.j : null;
  if (id !== hover) { hover = id; render(); }
});

$("incident").addEventListener("change", e => {
  incidentIdx = +e.target.value; step = 0; stop(); render();
});

addEventListener("keydown", e => {
  if (e.key === " ") { e.preventDefault(); playing = !playing; render(); tick(); }
  if (e.key === "ArrowRight") { stop(); step = Math.min(step + 1, steps().length - 1); render(); }
  if (e.key === "ArrowLeft") { stop(); step = Math.max(step - 1, 0); render(); }
  if (e.key.toLowerCase() === "r") { stop(); step = 0; render(); }
});

/* draggable split, the same 42-82% range the panes had */
(function drag(){
  const div = $("divider"), split = $("split");
  let on = false;
  const apply = () => split.style.gridTemplateColumns = `${splitPct}% 14px minmax(0,1fr)`;
  div.addEventListener("pointerdown", e => { e.preventDefault(); on = true; div.classList.add("drag"); });
  addEventListener("pointermove", e => {
    if (!on) return;
    const r = split.getBoundingClientRect();
    splitPct = Math.min(82, Math.max(42, (e.clientX - r.left) / r.width * 100));
    apply();
  });
  addEventListener("pointerup", () => { on = false; div.classList.remove("drag"); });
  div.addEventListener("dblclick", () => { splitPct = 70; apply(); });
  div.addEventListener("keydown", e => {
    if (e.key === "ArrowLeft") { splitPct = Math.max(42, splitPct - 2); apply(); }
    if (e.key === "ArrowRight") { splitPct = Math.min(82, splitPct + 2); apply(); }
  });
})();

boot.then(data => {
  D = data;
  if (!incident().arms[armKey]) armKey = Object.keys(incident().arms)[0];
  project();
  render();
}).catch(() => {
  $("page").innerHTML = '<div class="panel" style="flex:1;display:grid;place-items:center">' +
    '<div style="color:var(--ink3)">Loading the network…</div></div>';
});
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
    n3 = write_page("web/dashboard.html", DASHBOARD_HTML);
    print(f"[pages] index.html {n1} chars, board.html {n2} chars, dashboard.html {n3} chars");
}
