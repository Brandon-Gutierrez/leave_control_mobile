# Genera el ícono de "Salidas Temporales" (logo de Comteco + insignia roja con
# flechas de salida y retorno) en todos los tamaños de Android e iOS.
#
# Uso (desde control_leaves_mobile):
#   powershell -ExecutionPolicy Bypass -File tool/generate_icons.ps1
#
# Solo usa System.Drawing (Windows): no agrega dependencias a la app.
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$logo = [System.Drawing.Image]::FromFile((Join-Path $root 'rsc/comteco.png'))
$red = [System.Drawing.ColorTranslator]::FromHtml('#D32F2F')

# Dibuja el ícono en un cuadrado de $size px. $contentScale es la fracción del
# lado que ocupa el contenido (menor en el ícono adaptativo de Android, que el
# sistema recorta en círculo); $transparent deja el fondo sin pintar.
function New-Icon([int]$size, [double]$contentScale, [bool]$transparent) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.PixelOffsetMode = 'HighQuality'
    if ($transparent) { $g.Clear([System.Drawing.Color]::Transparent) } else { $g.Clear([System.Drawing.Color]::White) }

    $c = $size * $contentScale
    $logoW = $c * 0.92
    $logoH = $logoW * $logo.Height / $logo.Width
    $gap = $c * 0.04
    $d = $c * 0.34
    $top = ($size - ($logoH + $gap + $d)) / 2

    $g.DrawImage($logo, [single](($size - $logoW) / 2), [single]$top, [single]$logoW, [single]$logoH)

    # Insignia roja con dos flechas: arriba hacia afuera (salida), abajo de vuelta (retorno).
    $cx = $size / 2
    $cy = $top + $logoH + $gap + $d / 2
    $g.FillEllipse((New-Object System.Drawing.SolidBrush $red), [single]($cx - $d / 2), [single]($cy - $d / 2), [single]$d, [single]$d)

    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), ([single]($d * 0.075))
    $pen.StartCap = 'Round'
    $pen.EndCap = 'Round'
    $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
    $half = $d * 0.25
    $head = $d * 0.15
    foreach ($row in @(@{ y = $cy - $d * 0.13; dir = 1 }, @{ y = $cy + $d * 0.13; dir = -1 })) {
        $y = $row.y
        $dir = $row.dir
        $x1 = $cx - $dir * $half
        $x2 = $cx + $dir * $half
        $g.DrawLine($pen, [single]$x1, [single]$y, [single]($x2 - $dir * $head * 0.4), [single]$y)
        $points = @(
            (New-Object System.Drawing.PointF ([single]($x2 + $dir * $head * 0.35), [single]$y)),
            (New-Object System.Drawing.PointF ([single]($x2 - $dir * $head * 0.55), [single]($y - $head))),
            (New-Object System.Drawing.PointF ([single]($x2 - $dir * $head * 0.55), [single]($y + $head)))
        )
        $g.FillPolygon($white, [System.Drawing.PointF[]]$points)
    }
    $g.Dispose()
    return $bmp
}

function Save-Icon([string]$path, [int]$size, [double]$scale, [bool]$transparent) {
    $dir = Split-Path -Parent $path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    $bmp = New-Icon $size $scale $transparent
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

$fullScale = 0.90      # ícono completo (iOS y Android antiguo)
$adaptiveScale = 0.48  # primer plano adaptativo: dentro de la zona segura circular

# Imagen maestra (referencia, p. ej. para tiendas).
Save-Icon (Join-Path $root 'tool/icon/app_icon.png') 1024 $fullScale $false

# Android: ícono clásico y primer plano del ícono adaptativo (108 dp).
$res = Join-Path $root 'android/app/src/main/res'
$densities = @{ mdpi = 1.0; hdpi = 1.5; xhdpi = 2.0; xxhdpi = 3.0; xxxhdpi = 4.0 }
foreach ($name in $densities.Keys) {
    $k = $densities[$name]
    Save-Icon (Join-Path $res "mipmap-$name/ic_launcher.png") ([int](48 * $k)) $fullScale $false
    Save-Icon (Join-Path $res "mipmap-$name/ic_launcher_foreground.png") ([int](108 * $k)) $adaptiveScale $true
}

# iOS: todos los tamaños de AppIcon (sin transparencia).
$ios = Join-Path $root 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
$sizes = @{
    'Icon-App-20x20@1x.png' = 20; 'Icon-App-20x20@2x.png' = 40; 'Icon-App-20x20@3x.png' = 60
    'Icon-App-29x29@1x.png' = 29; 'Icon-App-29x29@2x.png' = 58; 'Icon-App-29x29@3x.png' = 87
    'Icon-App-40x40@1x.png' = 40; 'Icon-App-40x40@2x.png' = 80; 'Icon-App-40x40@3x.png' = 120
    'Icon-App-60x60@2x.png' = 120; 'Icon-App-60x60@3x.png' = 180
    'Icon-App-76x76@1x.png' = 76; 'Icon-App-76x76@2x.png' = 152
    'Icon-App-83.5x83.5@2x.png' = 167; 'Icon-App-1024x1024@1x.png' = 1024
}
foreach ($file in $sizes.Keys) {
    Save-Icon (Join-Path $ios $file) $sizes[$file] $fullScale $false
}

# Versión sin fondo (para usar sobre superficies claras en maquetas y documentos).
Save-Icon (Join-Path $root 'tool/icon/app_icon_transparent.png') 1024 0.92 $true

$logo.Dispose()
Write-Host 'Íconos generados.'
