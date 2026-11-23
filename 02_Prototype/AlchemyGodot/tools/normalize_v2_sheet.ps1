param(
    [Parameter(Mandatory=$true)][string]$Source,
    [Parameter(Mandatory=$true)][string]$Destination
)

Add-Type -AssemblyName System.Drawing
$sourceImage = [System.Drawing.Bitmap]::new($Source)
if ($sourceImage.Width -ne 3072 -or $sourceImage.Height -notin @(1536, 2048)) {
    $sourceImage.Dispose()
    throw "Expected a 6x3 or 6x4 sheet of 512px frames: $Source"
}
$sourceFrameCount = 6 * [int]($sourceImage.Height / 512)

$outputImage = [System.Drawing.Bitmap]::new(768, 512, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($outputImage)
$graphics.Clear([System.Drawing.Color]::Transparent)
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half

try {
    for ($index = 0; $index -lt 24; $index++) {
        $sourceIndex = [Math]::Min($index, $sourceFrameCount - 1)
        $sourceRect = [System.Drawing.Rectangle]::new(($sourceIndex % 6) * 512, [int][Math]::Floor($sourceIndex / 6) * 512, 512, 512)
        $targetRect = [System.Drawing.Rectangle]::new(($index % 6) * 128, [int][Math]::Floor($index / 6) * 128, 128, 128)
        $attributes = [System.Drawing.Imaging.ImageAttributes]::new()
        try {
            if ($index -ge $sourceFrameCount) {
                $alpha = [single]((24 - $index) / (25.0 - $sourceFrameCount))
                $matrix = [System.Drawing.Imaging.ColorMatrix]::new()
                $matrix.Matrix00 = 1; $matrix.Matrix11 = 1; $matrix.Matrix22 = 1; $matrix.Matrix33 = $alpha; $matrix.Matrix44 = 1
                $attributes.SetColorMatrix($matrix)
            }
            $graphics.DrawImage($sourceImage, $targetRect, $sourceRect.X, $sourceRect.Y,
                $sourceRect.Width, $sourceRect.Height, [System.Drawing.GraphicsUnit]::Pixel, $attributes)
        } finally {
            $attributes.Dispose()
        }
    }
    $outputImage.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $graphics.Dispose()
    $outputImage.Dispose()
    $sourceImage.Dispose()
}
