Get-ChildItem (Split-Path $MyInvocation.MyCommand.Path) -Filter *.trp | 
Foreach-Object {
$bytes = [System.IO.File]::ReadAllBytes($_.FullName);

$bytesOut = $bytes[64..($bytes.Count-1)];

[System.IO.File]::WriteAllBytes(($_.FullName + '.aqo'), $bytesOut);
}

Get-ChildItem (Split-Path $MyInvocation.MyCommand.Path) -Filter *.aqp | 
Foreach-Object {
$bytes = [System.IO.File]::ReadAllBytes($_.FullName);

$bytesOut = $bytes[64..($bytes.Count-1)];

[System.IO.File]::WriteAllBytes(($_.FullName + '.aqo'), $bytesOut);
}