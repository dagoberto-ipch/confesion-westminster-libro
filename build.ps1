$ErrorActionPreference = 'Stop'
$src = "apps/confesion-westminster/fuente/Confesion de fe Westminster - 1647 1903.txt"
$out = "apps/confesion-westminster/index.html"
$raw = [System.IO.File]::ReadAllText($src, [System.Text.Encoding]::UTF8)
$raw = $raw -replace "`r`n", "`n"
$lines = $raw -split "`n"

$hits = @()
for ($i = 0; $i -lt $lines.Length; $i++) {
  if ($lines[$i] -match '^CAP.{1,2}TULO\s+([IVXLCDM]+)\s*(.*)$') {
    $hits += [pscustomobject]@{ Idx = $i; Num = $Matches[1].Trim(); Title = ($Matches[2].Trim()) }
  }
}

function FixTitle([string]$num, [string]$t) {
  $t = ($t -replace '\s+', ' ').Trim()
  $map = @{
    'I'='De las Sagradas Escrituras'; 'II'='De Dios y de la Santísima Trinidad'; 'III'='Del Decreto Eterno de Dios'
    'IV'='De la Creación'; 'V'='De la Providencia'; 'VI'='De la Caída del Hombre, del Pecado y de su Castigo'
    'VII'='Del Pacto de Dios con el Hombre'; 'VIII'='De Cristo el Mediador'; 'IX'='Del Libre Albedrío'
    'X'='Del Llamamiento Eficaz'; 'XI'='De la Justificación'; 'XII'='De la Adopción'; 'XIII'='De la Santificación'
    'XIV'='De la Fe Salvadora'; 'XV'='Del Arrepentimiento para Vida'; 'XVI'='De las Buenas Obras'
    'XVII'='De la Perseverancia de los Santos'; 'XVIII'='De la Certeza de la Gracia y de la Salvación'
    'XIX'='De la Ley de Dios'; 'XX'='De la Libertad Cristiana y de la Libertad de Conciencia'
    'XXI'='Del Culto Religioso y del Día de Reposo'; 'XXII'='De los Juramentos Lícitos y de los Votos'
    'XXIII'='Del Magistrado Civil'; 'XXIV'='Del Matrimonio y del Divorcio'; 'XXV'='De la Iglesia'
    'XXVI'='De la Comunión de los Santos'; 'XXVII'='De los Sacramentos'; 'XXVIII'='Del Bautismo'
    'XXIX'='De la Cena del Señor'; 'XXX'='De las Censuras Eclesiásticas'; 'XXXI'='De los Sínodos y Concilios'
    'XXXII'='Del Estado del Hombre después de la Muerte y de la Resurrección de los Muertos'
    'XXXIII'='Del Juicio Final'; 'XXXIV'='Del Espíritu Santo'; 'XXXV'='Del Amor de Dios y de las Misiones'
  }
  if ($map.ContainsKey($num)) { return $map[$num] }
  return $t
}

$chapters = @()
for ($j = 0; $j -lt $hits.Count; $j++) {
  $start = $hits[$j].Idx + 1
  $end = if ($j -lt $hits.Count - 1) { $hits[$j + 1].Idx - 1 } else { $lines.Length - 1 }
  $num = $hits[$j].Num; $title = $hits[$j].Title
  if ($title -match 'LAS CENSURAS DE LA IGLESIA' -and $num -eq 'XXI') { $num = 'XXX' }
  if ($num -eq 'XXXII' -and $title -match 'Y LA\s*$') {
    $next = if ($start -le $end) { $lines[$start].Trim() } else { '' }
    if ($next -match '^RESURRECCION') { $title = ($title + ' ' + $next).Trim(); $start++ }
  }
  $title = FixTitle $num $title
  $bodyLines = @(); for ($k = $start; $k -le $end; $k++) { $bodyLines += $lines[$k] }
  $bi = 0; $bj = $bodyLines.Count - 1
  while ($bi -le $bj -and $bodyLines[$bi].Trim() -eq '') { $bi++ }
  while ($bj -ge $bi -and $bodyLines[$bj].Trim() -eq '') { $bj-- }
  if ($bj -ge $bi) { $bodyLines = $bodyLines[$bi..$bj] } else { $bodyLines = @() }
  $chapters += [pscustomobject]@{ n = $num; titulo = $title; lines = $bodyLines }
}

function EscHtml([string]$s) {
  if ($null -eq $s) { return '' }
  return $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;')
}

function BodyToHtml([string[]]$ls) {
  $sb = New-Object System.Text.StringBuilder
  $para = New-Object System.Collections.Generic.List[string]
  function FlushPara {
    if ($para.Count -gt 0) {
      $txt = (($para -join ' ') -replace '\s+', ' ').Trim()
      if ($txt.Length -gt 0) {
        $m = [regex]::Match($txt, '^([IVXLCDM]+)\.\s+(.*)$')
        if ($m.Success) {
          [void]$sb.Append("<p><span class='art-label'>" + $m.Groups[1].Value + ".</span> " + (EscHtml $m.Groups[2].Value) + "</p>")
        } else {
          [void]$sb.Append('<p>' + (EscHtml $txt) + '</p>')
        }
      }
      $para.Clear() | Out-Null
    }
  }
  foreach ($ln in $ls) {
    $t = $ln.TrimEnd()
    if ($t.Trim() -eq '') { FlushPara; continue }
    if ($t.Trim() -match '^[IVXLCDM]+\.$') { FlushPara; $para.Add($t.Trim()); continue }
    $para.Add($t.Trim())
  }
  FlushPara
  return $sb.ToString()
}

$data = @(); foreach ($c in $chapters) { $data += [pscustomobject]@{ n = $c.n; titulo = $c.titulo; html = (BodyToHtml $c.lines) } }
$json = $data | ConvertTo-Json -Depth 6 -Compress
$json = $json -replace '</script>', '<\/script>'

$bt = [char]96
$dq = [char]34
$jsRenderIndice = 'function renderIndice(){ indice.innerHTML = capitulos.map((c,i)=>' + $bt + '<a href="#${idCap(i)}" data-i="${i}"><span class="n">Cap. ${c.n}</span><span>${c.titulo}</span></a>' + $bt + ').join(' + $dq + $dq + '); }'
$jsPrev = $bt + '<a href="#${idCap(i-1)}" data-i="${i-1}">← Cap. ${capitulos[i-1].n}</a>' + $bt
$jsNext = $bt + '<a href="#${idCap(i+1)}" data-i="${i+1}">Cap. ${capitulos[i+1].n} →</a>' + $bt
$jsSection = $bt + '<section class="seccion" id="${idCap(i)}" data-i="${i}">' + "`n" + '      <div class="cabecera"><div class="eyebrow">Capítulo ${c.n}</div><h2 class="sec-titulo">${c.titulo}</h2></div>' + "`n" + '      <div class="contenido">${c.html}</div>' + "`n" + '      <div class="nav-cap">${prev}${next}</div>' + "`n" + '    </section>' + $bt
$jsRenderContenido = "function renderContenido(){`n  contenido.innerHTML = capitulos.map((c,i)=>{`n    const prev = i>0 ? $jsPrev : '<span class=`"disabled`">← Anterior</span>';`n    const next = i<capitulos.length-1 ? $jsNext : '<span class=`"disabled`">Siguiente →</span>';`n    return $jsSection;`n  }).join('');`n}"
$jsDonde = $bt + 'Cap. ${capitulos[actual].n} — ${capitulos[actual].titulo}' + $bt

$html = @"
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#2c3e50">
  <title>Confesión de Fe de Westminster (1647/1903) · Libro digital</title>
  <style>
    :root { --bg:#f7f4ee; --paper:#fffdf8; --ink:#24313a; --muted:#6b7b85; --accent:#7a4b12; --accent-2:#c9a227; --nav:#1f2d3a; --nav-ink:#eaf0f4; --line:#ddd6c8; --sidebar:320px; --serif:Georgia,"Iowan Old Style","Times New Roman",serif; --sans:"Segoe UI",Roboto,system-ui,-apple-system,Arial,sans-serif; }
    *{box-sizing:border-box} html{scroll-behavior:smooth}
    body{margin:0;background:var(--bg);color:var(--ink);font-family:var(--sans)}
    #portada{min-height:100vh;display:flex;align-items:center;justify-content:center;text-align:center;padding:48px 24px;color:#fff;position:relative;background:radial-gradient(120% 90% at 50% 0%,#3a4f63 0%,#223241 45%,#141e28 100%)}
    #portada::after{content:"";position:absolute;left:0;right:0;bottom:0;height:8px;background:var(--accent-2)}
    .portada-inner{max-width:860px}
    .logo-portada{display:block;width:min(220px,60vw);height:auto;margin:0 auto 22px;filter:drop-shadow(0 8px 22px rgba(0,0,0,.35))}
    .sello{display:inline-block;border:1px solid rgba(255,255,255,.45);border-radius:999px;padding:7px 18px;font-size:12px;letter-spacing:2.4px;text-transform:uppercase;color:#dfeaf2;margin-bottom:26px}
    #portada h1{font-family:var(--serif);font-size:clamp(34px,7vw,68px);line-height:1.05;margin:0 0 8px}
    .regla{width:140px;height:3px;background:var(--accent-2);margin:22px auto}
    #portada h2{font-family:var(--serif);font-weight:400;font-size:clamp(18px,3vw,28px);margin:0;color:#eaf3f9;line-height:1.35}
    .sub{margin-top:10px;font-size:13px;letter-spacing:2px;text-transform:uppercase;color:var(--accent-2)}
    .aviso{margin:22px auto 0;max-width:620px;font-size:13px;line-height:1.75;color:#c3d6e2}
    .acciones{display:flex;gap:14px;justify-content:center;flex-wrap:wrap;margin-top:36px}
    .btn{cursor:pointer;border:0;font-family:var(--sans);font-size:14px;font-weight:700;padding:14px 26px;border-radius:8px;transition:.18s}
    .btn-primario{background:var(--accent-2);color:#2b2100}.btn-primario:hover{filter:brightness(1.05)}
    .btn-fantasma{background:transparent;color:#fff;border:1.5px solid rgba(255,255,255,.55)}
    #app{display:none}#app.visible{display:block}
    .layout{display:flex;align-items:flex-start;min-height:100vh}
    aside{width:var(--sidebar);flex:0 0 var(--sidebar);background:var(--nav);color:var(--nav-ink);position:sticky;top:0;height:100vh;overflow-y:auto;border-right:1px solid #0f1820}
    .aside-top{padding:18px 18px 14px;border-bottom:1px solid rgba(255,255,255,.12);position:sticky;top:0;background:var(--nav);z-index:5}
    .marca b{font-size:13px;letter-spacing:1.2px;text-transform:uppercase;display:block}.marca small{color:#9fb3c2;font-size:11px}
    .controles{margin-top:12px;display:flex;gap:8px}
    .controles input{flex:1;padding:10px 12px;border-radius:7px;border:1px solid #314657;background:#16222d;color:#eaf3f9;font-size:13px}
    .controles input:focus{outline:none;border-color:var(--accent-2)}
    .indice-titulo{padding:14px 18px 6px;font-size:10.5px;letter-spacing:2px;text-transform:uppercase;color:#8ea4b5}
    nav a{display:flex;gap:10px;padding:10px 18px;text-decoration:none;color:#d5e2ec;font-size:13px;line-height:1.35;border-left:3px solid transparent}
    nav a:hover{background:#273848;color:#fff} nav a.activo{background:#2d4254;color:#fff;border-left-color:var(--accent-2);font-weight:600}
    nav a.oculto{display:none} nav a .n{flex:0 0 52px;font-size:11px;color:var(--accent-2);font-weight:700}
    .aside-foot{padding:14px 18px 22px;font-size:11px;color:#7f97a8;line-height:1.7;border-top:1px solid rgba(255,255,255,.1);margin-top:8px}
    main{flex:1;min-width:0;padding-bottom:90px}
    .barra-sup{position:sticky;top:0;z-index:20;background:rgba(247,244,238,.95);backdrop-filter:blur(6px);border-bottom:1px solid var(--line);padding:10px 22px;display:flex;align-items:center;gap:10px;flex-wrap:wrap}
    .barra-sup button{cursor:pointer;border:1px solid var(--line);background:#fff;border-radius:6px;padding:7px 12px;font-size:12.5px;color:var(--nav);font-weight:600}
    .barra-sup button:hover{background:var(--nav);color:#fff}
    .barra-sup .donde{font-size:12.5px;color:var(--muted);margin-left:auto}.barra-sup .donde b{color:var(--nav)}
    .seccion{max-width:760px;margin:0 auto;padding:42px 28px 8px}.seccion+.seccion{border-top:1px solid var(--line)}
    .cabecera{margin-bottom:22px;padding-bottom:16px;border-bottom:3px solid var(--accent-2)}
    .eyebrow{font-size:11px;letter-spacing:2.4px;text-transform:uppercase;color:var(--accent);font-weight:700}
    h2.sec-titulo{font-family:var(--serif);font-size:clamp(24px,4vw,34px);line-height:1.2;margin:8px 0 0;color:#1d2a35}
    .contenido{font-family:var(--serif);font-size:17px;line-height:1.8;color:#2b3841}
    .contenido p{margin:0 0 15px;text-align:justify;hyphens:auto}
    .art-label{font-family:var(--sans);font-size:12px;font-weight:800;letter-spacing:.8px;color:var(--accent);background:#f1e8d3;border-radius:4px;padding:2px 7px;margin-right:4px}
    .nav-cap{display:flex;justify-content:space-between;gap:12px;margin-top:28px;padding-top:18px;border-top:1px solid var(--line)}
    .nav-cap a,.nav-cap span{font-family:var(--sans);font-size:13px;font-weight:600;text-decoration:none;padding:10px 14px;border-radius:8px;border:1px solid var(--line);background:#fff;color:var(--nav)}
    .nav-cap a:hover{background:var(--nav);color:#fff}.nav-cap .disabled{opacity:.45;pointer-events:none}
    .pie{text-align:center;color:var(--muted);font-size:12px;padding:40px 24px 0;line-height:1.8}
    @media (max-width:900px){.layout{flex-direction:column}aside{position:relative;width:100%;flex:none;height:auto}aside.plegado nav,aside.plegado .aside-foot,aside.plegado .indice-titulo{display:none}.seccion{padding:30px 18px 8px}.barra-sup .donde{width:100%;margin-left:0}}
    @media print{aside,.barra-sup,.acciones,.nav-cap{display:none!important}#portada{display:none!important}#app{display:block!important}.seccion{max-width:100%;page-break-before:always;border:0}.seccion:first-of-type{page-break-before:auto}}
  </style>
</head>
<body>
<section id="portada">
  <div class="portada-inner">
    <img class="logo-portada" src="assets/marca_IPCH_Transparente_Vertical.png" alt="Iglesia Presbiteriana de Chile">
    <span class="sello">Documento histórico de la fe reformada</span>
    <h1>Confesión de Fe de Westminster</h1>
    <div class="regla"></div>
    <h2>Edición referencial 1647 / 1903</h2>
    <div class="sub">Libro digital · Portada, índice y capítulos navegables</div>
    <p class="aviso">Texto incorporado desde la fuente provista, con títulos normalizados. El libro incluye portada, índice, acceso directo por capítulos y menú de navegación entre secciones.</p>
    <div class="acciones">
      <button class="btn btn-primario" id="btnAbrir">Abrir el índice →</button>
      <button class="btn btn-fantasma" id="btnImprimir">Imprimir / PDF</button>
    </div>
  </div>
</section>
<div id="app">
  <div class="layout">
    <aside id="sidebar">
      <div class="aside-top">
        <div class="marca"><b>Confesión de Westminster</b><small>1647 / 1903</small></div>
        <div class="controles"><input type="search" id="q" placeholder="Buscar capítulo…" autocomplete="off" aria-label="Buscar capítulo"></div>
      </div>
      <div class="indice-titulo">Índice</div>
      <nav id="indice"></nav>
      <div class="aside-foot">Libro digital con contenido incorporado desde la fuente textual. Títulos normalizados y navegación por capítulos desde el índice o con Anterior/Siguiente.</div>
    </aside>
    <main>
      <div class="barra-sup">
        <button id="btnMenu" type="button">Menú</button>
        <button id="btnPortada" type="button">Portada</button>
        <button id="btnPrev" type="button">← Anterior</button>
        <button id="btnNext" type="button">Siguiente →</button>
        <div class="donde">Sección: <b id="donde">—</b></div>
      </div>
      <div id="contenido"></div>
      <div class="pie">Confesión de Fe de Westminster (1647/1903) · Libro digital navegable.</div>
    </main>
  </div>
</div>
<script>
const capitulos = $json;
const indice = document.getElementById('indice');
const contenido = document.getElementById('contenido');
const donde = document.getElementById('donde');
const sidebar = document.getElementById('sidebar');
let actual = 0;
function idCap(i){ return 'cap-' + (i + 1); }
$jsRenderIndice
$jsRenderContenido
function setActivo(i){
  actual = Math.max(0, Math.min(capitulos.length - 1, i));
  donde.textContent = $jsDonde;
  document.querySelectorAll('nav a').forEach(a => a.classList.toggle('activo', Number(a.dataset.i) === actual));
  history.replaceState(null, '', '#' + idCap(actual));
}
function irA(i){ setActivo(i); const el=document.getElementById(idCap(i)); if(el) el.scrollIntoView({behavior:'smooth',block:'start'}); if(window.innerWidth<=900) sidebar.classList.add('plegado'); }
renderIndice(); renderContenido();
document.getElementById('btnAbrir').addEventListener('click', ()=>{ document.getElementById('portada').style.display='none'; document.getElementById('app').classList.add('visible'); irA(0); });
document.getElementById('btnPortada').addEventListener('click', ()=>{ document.getElementById('app').classList.remove('visible'); document.getElementById('portada').style.display=''; window.scrollTo({top:0,behavior:'smooth'}); });
document.getElementById('btnImprimir').addEventListener('click', ()=>window.print());
document.getElementById('btnMenu').addEventListener('click', ()=>sidebar.classList.toggle('plegado'));
document.getElementById('btnPrev').addEventListener('click', ()=>irA(actual-1));
document.getElementById('btnNext').addEventListener('click', ()=>irA(actual+1));
indice.addEventListener('click', (e)=>{ const a=e.target.closest('a[data-i]'); if(!a) return; e.preventDefault(); document.getElementById('portada').style.display='none'; document.getElementById('app').classList.add('visible'); irA(Number(a.dataset.i)); });
contenido.addEventListener('click', (e)=>{ const a=e.target.closest('a[data-i]'); if(!a) return; e.preventDefault(); irA(Number(a.dataset.i)); });
document.getElementById('q').addEventListener('input', (e)=>{ const q=e.target.value.toLowerCase().trim(); document.querySelectorAll('nav a').forEach(a=>{ a.classList.toggle('oculto', q && !a.textContent.toLowerCase().includes(q)); }); });
const obs = new IntersectionObserver((entries)=>{ entries.forEach(en=>{ if(en.isIntersecting) setActivo(Number(en.target.dataset.i)); }); }, { rootMargin:'-30% 0px -60% 0px', threshold:0.01 });
document.querySelectorAll('.seccion').forEach(s=>obs.observe(s));
window.addEventListener('hashchange', ()=>{ const m=location.hash.match(/^#cap-(\d+)$/); if(m){ document.getElementById('portada').style.display='none'; document.getElementById('app').classList.add('visible'); setActivo(Number(m[1])-1); } });
</script>
</body>
</html>
"@

[System.IO.File]::WriteAllText($out, $html, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "OK chapters=$($chapters.Count) out=$out"
