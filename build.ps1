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

function TitleCaseEs([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return $s }
  $lower = $s.ToLowerInvariant()
  $small = @('de','del','la','las','el','los','y','e','o','u','a','con','para','por','en','al','su','sus','un','una')
  $words = $lower -split '\s+'
  for ($i=0; $i -lt $words.Count; $i++) {
    $w = $words[$i]
    if ($w.Length -eq 0) { continue }
    if ($i -gt 0 -and $small -contains $w) { $words[$i] = $w; continue }
    $first = $w.Substring(0,1).ToUpperInvariant()
    $rest = if ($w.Length -gt 1) { $w.Substring(1) } else { '' }
    $words[$i] = $first + $rest
  }
  return ($words -join ' ')
}

function FixTitle([string]$num, [string]$t) {
  $t = ($t -replace '\s+', ' ').Trim()
  # known full-title fixes based on standard text / source intent
  $map = @{
    'I'='De las Sagradas Escrituras'
    'II'='De Dios y de la Santísima Trinidad'
    'III'='Del Decreto Eterno de Dios'
    'IV'='De la Creación'
    'V'='De la Providencia'
    'VI'='De la Caída del Hombre, del Pecado y de su Castigo'
    'VII'='Del Pacto de Dios con el Hombre'
    'VIII'='De Cristo el Mediador'
    'IX'='Del Libre Albedrío'
    'X'='Del Llamamiento Eficaz'
    'XI'='De la Justificación'
    'XII'='De la Adopción'
    'XIII'='De la Santificación'
    'XIV'='De la Fe Salvadora'
    'XV'='Del Arrepentimiento para Vida'
    'XVI'='De las Buenas Obras'
    'XVII'='De la Perseverancia de los Santos'
    'XVIII'='De la Certeza de la Gracia y de la Salvación'
    'XIX'='De la Ley de Dios'
    'XX'='De la Libertad Cristiana y de la Libertad de Conciencia'
    'XXI'='Del Culto Religioso y del Día de Reposo'
    'XXII'='De los Juramentos Lícitos y de los Votos'
    'XXIII'='Del Magistrado Civil'
    'XXIV'='Del Matrimonio y del Divorcio'
    'XXV'='De la Iglesia'
    'XXVI'='De la Comunión de los Santos'
    'XXVII'='De los Sacramentos'
    'XXVIII'='Del Bautismo'
    'XXIX'='De la Cena del Señor'
    'XXX'='De las Censuras Eclesiásticas'
    'XXXI'='De los Sínodos y Concilios'
    'XXXII'='Del Estado del Hombre después de la Muerte y de la Resurrección de los Muertos'
    'XXXIII'='Del Juicio Final'
    'XXXIV'='Del Espíritu Santo'
    'XXXV'='Del Amor de Dios y de las Misiones'
  }
  if ($map.ContainsKey($num)) { return $map[$num] }
  return (TitleCaseEs $t)
}

$chapters = @()
for ($j = 0; $j -lt $hits.Count; $j++) {
  $start = $hits[$j].Idx + 1
  $end = if ($j -lt $hits.Count - 1) { $hits[$j + 1].Idx - 1 } else { $lines.Length - 1 }
  $num = $hits[$j].Num
  $title = $hits[$j].Title

  if ($title -match 'LAS CENSURAS DE LA IGLESIA' -and $num -eq 'XXI') { $num = 'XXX' }
  if ($num -eq 'XXXII' -and $title -match 'Y LA\s*$') {
    $next = if ($start -le $end) { $lines[$start].Trim() } else { '' }
    if ($next -match '^RESURRECCION') { $title = ($title + ' ' + $next).Trim(); $start++ }
  }
  $title = FixTitle $num $title

  $bodyLines = @()
  for ($k = $start; $k -le $end; $k++) { $bodyLines += $lines[$k] }
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
          [void]$sb.Append("<p><span class='art-label'>$($m.Groups[1].Value).</span> " + (EscHtml $m.Groups[2].Value) + "</p>")
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

$data = @()
foreach ($c in $chapters) { $data += [pscustomobject]@{ n = $c.n; titulo = $c.titulo; html = (BodyToHtml $c.lines) } }
$json = $data | ConvertTo-Json -Depth 6 -Compress
$json = $json -replace '</script>', '<\/script>'

$template = Get-Content -LiteralPath $out -Raw -Encoding UTF8
# replace the embedded capitulos array
$pattern = 'const capitulos = .*?;\r?\nconst indice'
$replacement = "const capitulos = $json;`nconst indice"
$new = [regex]::Replace($template, $pattern, $replacement, [System.Text.RegularExpressions.RegexOptions]::Singleline)
if ($new -eq $template) { throw 'No se pudo reemplazar el bloque de capitulos' }
# update sidebar/footer note
$new = $new -replace 'Libro digital con contenido incorporado desde la fuente textual\. Navega por capítulos desde el índice o con Anterior/Siguiente\.', 'Libro digital con contenido incorporado desde la fuente textual. Títulos normalizados y navegación por capítulos desde el índice o con Anterior/Siguiente.'
$new = $new -replace 'Texto incorporado desde la fuente provista\. El libro incluye portada, índice, acceso directo por capítulos y menú de navegación entre secciones\.', 'Texto incorporado desde la fuente provista, con títulos normalizados. El libro incluye portada, índice, acceso directo por capítulos y menú de navegación entre secciones.'

[System.IO.File]::WriteAllText($out, $new, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "OK chapters=$($chapters.Count) updated=$out"
