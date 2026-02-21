# Configuración de consola para evitar errores de salida
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Start-SuperScraper {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Url
    )

# la linea de la 1 hasta esta que es la 10 es para configurar para que la consola no de error de datos de salida cuestion de que lea emoji y simbolos raros como palabras con acentos.

    try {
        # 1. Definir rutas (Se creará en la misma carpeta del script)
        $scriptPath = $PSScriptRoot
        if ([string]::IsNullOrEmpty($scriptPath)) { $scriptPath = "." }

        $domain = ([System.Uri]$Url).Host -replace 'www\.', ''
        $folderPath = Join-Path $scriptPath "Datos_$domain"

        if (-not (Test-Path $folderPath)) {
            New-Item -ItemType Directory -Path $folderPath | Out-Null
        }     

$userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

Write-Host "--- Iniciando scraping de: $Url ---" -ForegroundColor Cyan

# Peticion Web
$web = Invoke-WebRequest -Uri $Url -UserAgent $userAgent -UseBasicParsing -TimeoutSec 20
$content = $web.Content

# 2. Extraccion de datos
$titles = [regex]::Matches($content, '(?<=(<h[1-2][^>]*>)(.*?)(?=</h[1-2]>))') |
ForEach-Object { $_.Value -replace '<[^>]+', '' } | Select-Object -Unique -First 15

$prices = [regex]::Matches($content, '(\$|USD|EUR|MXN|S/|PEN)\s?\d+(.\d{2})?') |
Select-Object -ExpandProperty Value -Unique

$emails = [regex]::Matches($content, '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}') |
Select-Object -ExpandProperty Value -Unique

# Estructura de objeto para JSON y CSV
$dataObject = [PSCustomObject]@{
    Url      = $Url
    Fecha    = Get-Date -Format "yyyy-MM-dd HH:mm"
    Titulos  = $titles
    Precios  = $prices
    Correos  = $emails
}

# 3. GUARDAR EN LOS 3 FORMATOS

# FORMATO 1: TXT (Reporte humano)
$reportTxt = "$folderPath\reporte.txt"

"=== REPORTE PARA: $Url ===`r`n`nTITULOS:`r`n$($titles -join "`r`n")`r`n`nPRECIOS:`r`n$($prices -join "`r`n")`r`n`nCORREOS:`r`n$($emails -join "`r`n")" |
    Out-File $reportTxt -Encoding UTF8

    # FORMATO 2: JSON (Para programadores)
$dataObject | ConvertTo-Json | Out-File "$folderPath\datos.json" -Encoding UTF8

# FORMATO 3: CSV (Para Excel)
# Nota: En CSV guardamos las listas como una sola cadena de texto separada por puntos y comas
$csvObject = [PSCustomObject]@{
    Url     = $Url
    Titulos = $titles -join " | "
    Precios = $prices -join " | "
    Correos = $emails -join " | "
}

$csvObject | Export-Csv -Path "$folderPath\datos.csv" -NoTypeInformation -Encoding UTF8 -Delimiter ","

Write-Host "[OK] Archivos generados: TXT, JSON y CSV" -ForegroundColor Green

# 4. Descarga de fotos
Write-Host "--- Descargando fotos encontradas ---" -ForegroundColor Yellow

$imgUrls = [regex]::Matches($content, '(?<=<img [^>]*src=")(https?://[^"]+\.(jpg|png|webp))') |
    Select-Object -ExpandProperty Value -Unique |
    Select-Object -First 5

$count = 1

foreach ($img in $imgUrls) {
    try {
        $ext = ".jpg"
        if ($img -match "\.png") { $ext = ".png" }

        $dest = Join-Path $folderPath "imagen_$count$ext"

        Invoke-WebRequest -Uri $img -OutFile $dest -UserAgent $userAgent

        Write-Host " + Foto $count lista" -ForegroundColor Gray
        $count++
    }
    catch {
        Write-Host " - Error en una imagen" -ForegroundColor Red
    }
}

Write-Host "--- PROCESO COMPLETADO EN LA CARPETA LOCAL ---" -ForegroundColor Green
} catch {
    Write-Host "Error en el script: $($_.Exception.Message)" -ForegroundColor Red
}

}

# Ejecucion
$urlInput = Read-Host "Pega la URL aqui"
Start-SuperScraper -Url $urlInput







