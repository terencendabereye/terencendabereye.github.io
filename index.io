<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Linear Interpolator — Offline</title>
  <style>
    :root{font-family:system-ui,-apple-system,Segoe UI,Roboto,'Helvetica Neue',Arial;}
    body{max-width:900px;margin:18px auto;padding:18px}
    h1{font-size:1.4rem;margin-bottom:6px}
    .card{border-radius:12px;padding:12px;margin:8px 0;border:1px solid #ddd}
    table{width:100%;border-collapse:collapse}
    th,td{padding:6px;border-bottom:1px solid #eee;text-align:left}
    input[type=number]{width:100px}
    .row{display:flex;gap:8px;flex-wrap:wrap;align-items:center}
    button{padding:8px 10px;border-radius:8px;border:0;background:#222;color:#fff}
    button.ghost{background:transparent;color:#222;border:1px solid #ccc}
    .small{padding:6px 8px;font-size:0.9rem}
    canvas{width:100%;height:220px;border:1px solid #eee;border-radius:8px}
    .muted{color:#666;font-size:0.9rem}
    footer{margin-top:12px;font-size:0.9rem;color:#444}
  </style>
</head>
<body>
  <h1>Linear Interpolator — Offline</h1>
  <div class="card">
    <div class="row">
      <div style="flex:1">
        <div class="muted">Enter (x, y) sample points. You can add many points; interpolation is piecewise linear between sorted x values.</div>
      </div>
      <div>
        <button id="addPoint" class="small">Add point</button>
        <button id="clearAll" class="small ghost">Clear</button>
      </div>
    </div>

    <table id="pointsTable" style="margin-top:8px">
      <thead><tr><th>x</th><th>y</th><th style="width:120px">actions</th></tr></thead>
      <tbody></tbody>
    </table>
    <div style="margin-top:8px;display:flex;gap:8px;flex-wrap:wrap;align-items:center">
      <label>Query x: <input id="queryX" type="number" step="any" value="0"></label>
      <button id="interp" class="small">Interpolate</button>
      <div id="result" class="muted">Result: —</div>
    </div>

    <div style="margin-top:8px;display:flex;gap:8px;align-items:center;flex-wrap:wrap">
      <button id="exportJson" class="small ghost">Export JSON</button>
      <button id="importJson" class="small ghost">Import JSON</button>
      <input id="fileInput" type="file" accept="application/json" style="display:none">
      <button id="downloadCsv" class="small ghost">Download CSV</button>
      <button id="loadSample" class="small">Load sample</button>
    </div>

  </div>

  <div class="card">
    <canvas id="plot" width="800" height="240"></canvas>
    <div class="muted">Tap a point in the table to edit. Dragging not required — simple tap edits. Works completely offline when file is stored on your device.</div>
  </div>

  <footer>
    Notes: This is a single-file offline app. Save this file to your phone and open it in your browser (Chrome/Edge/Safari). For full PWA installability you'd need to host it once (or use GitHub Pages) so the browser can register a service worker and a manifest. If you want that, tell me and I will generate the service worker + manifest files.
  </footer>

<script>
// --- data model ---
let points = [];
const tbody = document.querySelector('#pointsTable tbody');
const queryX = document.getElementById('queryX');
const resultEl = document.getElementById('result');
const plot = document.getElementById('plot');
const ctx = plot.getContext('2d');

function renderTable(){
  tbody.innerHTML='';
  points.forEach((p,i)=>{
    const tr = document.createElement('tr');
    const tdX = document.createElement('td');
    const inputX = document.createElement('input'); inputX.type='number'; inputX.value=p.x; inputX.style.width='80px';
    inputX.onchange = ()=>{ points[i].x = Number(inputX.value); sortAndRender(); };
    tdX.appendChild(inputX);
    const tdY = document.createElement('td');
    const inputY = document.createElement('input'); inputY.type='number'; inputY.value=p.y; inputY.style.width='80px';
    inputY.onchange = ()=>{ points[i].y = Number(inputY.value); sortAndRender(); };
    tdY.appendChild(inputY);
    const tdA = document.createElement('td');
    const del = document.createElement('button'); del.textContent='Del'; del.className='small ghost';
    del.onclick = ()=>{ points.splice(i,1); sortAndRender(); }
    tdA.appendChild(del);
    tr.appendChild(tdX); tr.appendChild(tdY); tr.appendChild(tdA);
    tbody.appendChild(tr);
  })((p,i)=>{
    const tr = document.createElement('tr');
    const tdX = document.createElement('td'); tdX.textContent = p.x;
    const tdY = document.createElement('td'); tdY.textContent = p.y;
    const tdA = document.createElement('td');
    const edit = document.createElement('button'); edit.textContent='Edit'; edit.className='small';
    edit.onclick = ()=> editPoint(i);
    const del = document.createElement('button'); del.textContent='Del'; del.className='small ghost';
    del.onclick = ()=>{ points.splice(i,1); sortAndRender(); }
    tdA.appendChild(edit); tdA.appendChild(del);
    tr.appendChild(tdX); tr.appendChild(tdY); tr.appendChild(tdA);
    tbody.appendChild(tr);
  })
  drawPlot();
}

function sortAndRender(){
  points.sort((a,b)=>Number(a.x)-Number(b.x));
  renderTable();
}

function addPoint(x=0,y=0){
  points.push({x: Number(x), y: Number(y)});
  sortAndRender();
}

function editPoint(i){
  const p = points[i];
  const newX = prompt('x value', String(p.x));
  if(newX===null) return;
  const newY = prompt('y value', String(p.y));
  if(newY===null) return;
  points[i] = {x: Number(newX), y: Number(newY)};
  sortAndRender();
}

function interp(x){
  if(points.length===0) return NaN;
  // if exact x exists
  for(const p of points){ if(Number(p.x)===Number(x)) return Number(p.y); }
  // outside range: linear extrapolate using end segment
  const xs = points.map(p=>Number(p.x));
  if(x < xs[0]){
    const a = points[0], b = points[1] || points[0];
    return linearBetween(a,b,x);
  }
  if(x > xs[xs.length-1]){
    const a = points[points.length-2] || points[points.length-1], b = points[points.length-1];
    return linearBetween(a,b,x);
  }
  // find interval
  for(let i=0;i<points.length-1;i++){
    const a = points[i], b = points[i+1];
    if(x>Number(a.x) && x<Number(b.x)) return linearBetween(a,b,x);
    if(Number(x)===Number(a.x)) return Number(a.y);
  }
  return NaN;
}
function linearBetween(a,b,x){
  const x0 = Number(a.x), y0 = Number(a.y), x1=Number(b.x), y1=Number(b.y);
  if(x1===x0) return (y0+y1)/2;
  const t = (x - x0)/(x1 - x0);
  return y0 + t*(y1-y0);
}

// --- UI actions ---
document.getElementById('addPoint').onclick = ()=>{
  addPoint(0,0);
};
document.getElementById('clearAll').onclick = ()=>{ if(confirm('Clear all points?')){ points=[]; sortAndRender(); resultEl.textContent='Result: —'; } }

document.getElementById('interp').onclick = ()=>{
  const x = Number(queryX.value);
  const y = interp(x);
  if(Number.isNaN(y)) resultEl.textContent = 'Result: not available';
  else resultEl.textContent = 'Result: y = ' + y;
  drawPlot(x,y);
}

// export / import
function download(filename, text){
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([text],{type:'application/json'}));
  a.download = filename; document.body.appendChild(a); a.click(); a.remove();
}

document.getElementById('exportJson').onclick = ()=>{
  download('points.json', JSON.stringify(points,null,2));
}

const fileInput = document.getElementById('fileInput');
document.getElementById('importJson').onclick = ()=> fileInput.click();
fileInput.onchange = e => {
  const f = e.target.files[0]; if(!f) return;
  const r = new FileReader();
  r.onload = ev=>{ try{ const data = JSON.parse(ev.target.result); if(Array.isArray(data)){ points = data.map(p=>({x:Number(p.x),y:Number(p.y)})); sortAndRender(); } else alert('JSON should be an array of {x,y}'); } catch(err){alert('Invalid JSON: '+err)} }
  r.readAsText(f);
}

document.getElementById('downloadCsv').onclick = ()=>{
  if(points.length===0){ alert('No points'); return; }
  const rows = ['x,y', ...points.map(p=>`${p.x},${p.y}`)];
  const csv = rows.join('\n');
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([csv],{type:'text/csv'})); a.download='points.csv'; document.body.appendChild(a); a.click(); a.remove();
}

document.getElementById('loadSample').onclick = ()=>{
  points = [{x:0,y:0},{x:1,y:2},{x:3,y:1},{x:6,y:4}]; sortAndRender();
}

// --- plotting ---
function drawPlot(highlightX, highlightY){
  const dpr = Math.max(1, window.devicePixelRatio || 1);
  plot.width = plot.clientWidth * dpr;
  plot.height = plot.clientHeight * dpr;
  ctx.setTransform(dpr,0,0,dpr,0,0);
  ctx.clearRect(0,0,plot.clientWidth,plot.clientHeight);
  // axes
  ctx.fillStyle = '#fff'; ctx.fillRect(0,0,plot.clientWidth,plot.clientHeight);
  if(points.length===0) return;
  const pad = 30; const W = plot.clientWidth, H = plot.clientHeight;
  const xs = points.map(p=>Number(p.x)); const ys = points.map(p=>Number(p.y));
  const xmin = Math.min(...xs); const xmax = Math.max(...xs);
  const ymin = Math.min(...ys); const ymax = Math.max(...ys);
  const xrange = (xmax===xmin)? 1 : (xmax-xmin);
  const yrange = (ymax===ymin)? 1 : (ymax-ymin);
  function px(x){ return pad + ((x - xmin)/xrange)*(W-2*pad); }
  function py(y){ return H - pad - ((y - ymin)/yrange)*(H-2*pad); }
  // grid
  ctx.strokeStyle='#eee'; ctx.lineWidth=1;
  ctx.beginPath(); ctx.moveTo(pad, pad); ctx.lineTo(pad, H-pad); ctx.lineTo(W-pad, H-pad); ctx.stroke();
  // lines
  ctx.beginPath(); ctx.lineWidth=2; ctx.strokeStyle='#0077cc';
  points.forEach((p,i)=>{
    const x = px(p.x), y = py(p.y);
    if(i===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
  }); ctx.stroke();
  // points
  ctx.fillStyle='#222';
  points.forEach(p=>{ const x=px(p.x), y=py(p.y); ctx.beginPath(); ctx.arc(x,y,4,0,Math.PI*2); ctx.fill(); });
  // highlight query
  if(typeof highlightX!=='undefined' && !Number.isNaN(highlightY)){
    ctx.fillStyle='#d00'; const x=px(highlightX||highlightX), y=py(highlightY);
    ctx.beginPath(); ctx.arc(x,y,5,0,Math.PI*2); ctx.fill();
  }
}

// init
sortAndRender();

// allow keyboard enter in query
queryX.addEventListener('keydown', e=>{ if(e.key==='Enter') document.getElementById('interp').click(); });
</script>
</body>
</html>
