param([int]$Port = 5173, [string]$Root = (Split-Path -Parent $PSScriptRoot))

# Minimal static file server for local preview (no node/python on this machine).
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path $Root).Path

$types = @{
  '.html'='text/html; charset=utf-8'; '.htm'='text/html; charset=utf-8'
  '.css'='text/css; charset=utf-8';   '.js'='application/javascript; charset=utf-8'
  '.json'='application/json';         '.svg'='image/svg+xml'
  '.jpg'='image/jpeg';                '.jpeg'='image/jpeg'
  '.png'='image/png';                 '.webp'='image/webp'
  '.gif'='image/gif';                 '.mp4'='video/mp4'
  '.woff'='font/woff';                '.woff2'='font/woff2'
  '.ico'='image/x-icon';              '.txt'='text/plain; charset=utf-8'
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $Root on http://localhost:$Port/"

while ($listener.IsListening) {
  try {
    $ctx = $listener.GetContext()
    $rel = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
    if ([string]::IsNullOrWhiteSpace($rel)) { $rel = 'index.html' }
    $path = Join-Path $Root ($rel -replace '/', '\')

    if ((Test-Path $path) -and (Get-Item $path).PSIsContainer) { $path = Join-Path $path 'index.html' }

    # Keep the server inside the project folder.
    $full = $null
    if (Test-Path $path) { $full = (Resolve-Path $path).Path }

    if ($full -and $full.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase) -and -not (Get-Item $full).PSIsContainer) {
      $ext = [System.IO.Path]::GetExtension($full).ToLower()
      $ctx.Response.ContentType = if ($types.ContainsKey($ext)) { $types[$ext] } else { 'application/octet-stream' }
      $ctx.Response.Headers.Add('Cache-Control', 'no-store')
      $bytes = [System.IO.File]::ReadAllBytes($full)
      $ctx.Response.ContentLength64 = $bytes.Length
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
      Write-Host "200 /$rel"
    } else {
      $ctx.Response.StatusCode = 404
      $msg = [System.Text.Encoding]::UTF8.GetBytes('404')
      $ctx.Response.OutputStream.Write($msg, 0, $msg.Length)
      Write-Host "404 /$rel"
    }
    $ctx.Response.OutputStream.Close()
  } catch {
    Write-Host "ERR $($_.Exception.Message)"
  }
}
