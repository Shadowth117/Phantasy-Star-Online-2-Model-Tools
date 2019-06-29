param(
	[System.IO.DirectoryInfo]$pathParam = $null
)

[System.IO.DirectoryInfo]$path

if($pathParam) {
    $path = (Get-Item -Path $pathParam)
    if($path -isnot [System.IO.DirectoryInfo]) { 
		throw [System.IO.DirectoryNotFoundException]::new("Path is not a directory: $pathParam") 
	}
} else {
    [System.Management.Automation.PathInfo] $path = (Get-Location)
}

Get-ChildItem -Path $path -Filter *.trp | 
	Foreach-Object {
		$PSItem.FullName
		$bytes = [System.IO.File]::ReadAllBytes($PSItem.FullNupdaame);
		
		$bytesOut = $bytes[64..($bytes.Count-1)];
		
		[System.IO.File]::WriteAllBytes(($_.FullName + '.aqo'), $bytesOut);
	}

Get-ChildItem -Path $path -Filter *.aqp | 
	Foreach-Object {
		$PSItem.FullName
		$bytes = [System.IO.File]::ReadAllBytes($PSItem.FullName);
		
		$bytesOut = $bytes[64..($bytes.Count-1)];
		
		[System.IO.File]::WriteAllBytes(($_.FullName + '.aqo'), $bytesOut);
	}
