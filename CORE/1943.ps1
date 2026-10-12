param(
    [Parameter(ValueFromRemainingArguments=$true, Position=0)][string[]]$Zips = @('1943.zip'),
    [Alias('o')][string]$Out = 'arcade/1943'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$base = $PSScriptRoot
if (-not $base) { $base = (Get-Location).Path }
if (-not [IO.Path]::IsPathRooted($Out)) { $Out = Join-Path $base $Out }
$Out = [IO.Path]::GetFullPath($Out)
$chips = @{}
foreach ($zip in $Zips) {
    if (-not [IO.Path]::IsPathRooted($zip)) { $zip = Join-Path $base $zip }
    $archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $zip).Path)
    try {
        foreach ($entry in $archive.Entries) {
            if (-not $entry.Name) { continue }
            $stream = $entry.Open()
            try {
                $mem = New-Object IO.MemoryStream
                try { $stream.CopyTo($mem); $chips[$entry.Name.ToLowerInvariant()] = $mem.ToArray() }
                finally { $mem.Dispose() }
            } finally { $stream.Dispose() }
        }
    } finally { $archive.Dispose() }
}
function Chip([string]$name) {
    if (-not $chips.ContainsKey($name)) { throw "Missing ROM chip: $name" }
    return ,([byte[]]$chips[$name])
}
function Join-Chips([object[]]$parts) {
    $mem = New-Object IO.MemoryStream
    try { foreach ($part in $parts) { $mem.Write($part,0,$part.Length) }; return ,$mem.ToArray() }
    finally { $mem.Dispose() }
}
function Interleave([byte[]]$a,[byte[]]$b) {
    if ($a.Length -ne $b.Length) { throw 'Lane length mismatch' }
    $out = New-Object byte[] ($a.Length * 2)
    for ($i=0;$i -lt $a.Length;$i++) { $out[2*$i]=$a[$i]; $out[2*$i+1]=$b[$i] }
    return ,$out
}
function Swap16([byte[]]$a) {
    if ($a.Length % 2) { throw 'Odd ROM size' }
    $out = [byte[]]$a.Clone()
    for ($i=0;$i -lt $a.Length;$i+=2) { $out[$i]=$a[$i+1];$out[$i+1]=$a[$i] }
    return ,$out
}
function Sort-Rom([byte[]]$a,[string]$mode) {
    $out = New-Object byte[] $a.Length
    for ($i=0;$i -lt $a.Length;$i++) {
        if ($mode -eq 'obj') { $dst=($i -band (-bnot 0x7c)) -bor (($i -band 0x40) -shr 4) -bor (($i -band 0x3c) -shl 1) }
        else { $dst=($i -band (-bnot 0x1e)) -bor (($i -band 0x10) -shr 3) -bor (($i -band 0x0e) -shl 1) }
        $out[$dst]=$a[$i]
    }
    return ,$out
}
function CRC32([byte[]]$bytes) {
    [long]$crc=4294967295
    foreach ($b in $bytes) {
        $crc=$crc -bxor [long]$b
        for($j=0;$j -lt 8;$j++) {
            if ($crc -band 1) { $crc=(($crc -shr 1) -bxor [long]3988292384) -band [long]4294967295 }
            else { $crc=($crc -shr 1) -band [long]4294967295 }
        }
    }
    return (($crc -bxor [long]4294967295) -band [long]4294967295)
}
$spec = [ordered]@{
    main = @('bme01.12d', 'bme02.13d', 'bme03.14d')
    sound = @('bm05.4k')
    char = @('bm04.5h')
    map1 = @('bm14.5f')
    map2 = @('bm23.8k')
    scr1 = @('bm15.10f', 'bm16.11f', 'bm17.12f', 'bm18.14f', 'bm19.10j', 'bm20.11j', 'bm21.12j', 'bm22.14j')
    scr2 = @('bm24.14k', 'bm25.14l')
    obj = @('bm06.10a', 'bm07.11a', 'bm08.12a', 'bm09.14a', 'bm10.10c', 'bm11.11c', 'bm12.12c', 'bm13.14c')
    prom = @('bm.7k', 'bm10.7l', 'bm11.12l', 'bm1.12a', 'bm12.12m', 'bm2.13a', 'bm3.14a', 'bm4.12c', 'bm5.7f', 'bm6.4b', 'bm7.7c', 'bm8.8c', 'bm9.6l')
}
$sizes = @{main=163840;sound=32768;char=32768;map1=32768;map2=32768;scr1=262144;scr2=65536;obj=262144;prom=7168}
[IO.Directory]::CreateDirectory($Out) | Out-Null
foreach ($region in $spec.Keys) {
    $parts = @(); foreach ($n in $spec[$region]) { $parts += ,(Chip $n) }
    switch ($region) {
        {$_ -in 'char','map1','map2'} { $data=Swap16 $parts[0]; break }
        'scr2' { $data=Interleave $parts[1] $parts[0]; break }
        {$_ -in 'scr1','obj'} {
            $seq=@(4,0,5,1,6,2,7,3); $blocks=@()
            for($i=0;$i -lt 8;$i+=2) { $blocks += ,(Interleave $parts[$seq[$i]] $parts[$seq[$i+1]]) }
            $data=Join-Chips $blocks; break
        }
        default { $data=Join-Chips $parts }
    }
    if ($region -in 'map1','map2') { $data=Sort-Rom $data 'map' }
    if ($region -eq 'obj') { $data=Sort-Rom $data 'obj' }
    $name="1943_${region}.rom"
    if ($data.Length -ne $sizes[$region]) { throw "Wrong size for ${name}: $($data.Length) expected $($sizes[$region])" }
    [IO.File]::WriteAllBytes((Join-Path $Out $name),[byte[]]$data)
    '{0,-20} {1,7} bytes  CRC32 {2:X8}' -f $name,$data.Length,(CRC32 $data)
}
'Object sorting: hvvvvxx; map sorting: hvvvx'
