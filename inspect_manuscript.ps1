$ErrorActionPreference = 'Stop'
$path = Join-Path $PSScriptRoot 'manuscript_source.doc'
$word = New-Object -ComObject Word.Application
$word.Visible = $false
try {
    $doc = $word.Documents.Open($path, $false, $true)
    $text = $doc.Content.Text
    [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'manuscript_text.txt'), $text, [System.Text.Encoding]::UTF8)
    Write-Output ("Characters extracted: {0}" -f $text.Length)
}
finally {
    if ($doc) { $doc.Close($false) }
    $word.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
}
