﻿# Set-ExecutionPolicy RemoteSigned

Clear-Host
Function DownloadFileWithProgress {

# Code for this function borrowed from http://poshcode.org/2461
# Thanks Crazy Dave

	param(
		[Parameter(Mandatory=$true)]
		[String] $url,
		[Parameter(Mandatory=$false)]
		[String] $localFile = (Join-Path $pwd.Path $url.SubString($url.LastIndexOf('/'))) 
	)
		
	begin {
		$client = New-Object System.Net.WebClient
		$Global:downloadComplete = $false
		$eventDataComplete = Register-ObjectEvent $client DownloadFileCompleted `
			-SourceIdentifier WebClient.DownloadFileComplete `
			-Action {$Global:downloadComplete = $true}
		$eventDataProgress = Register-ObjectEvent $client DownloadProgressChanged `
			-SourceIdentifier WebClient.DownloadProgressChanged `
			-Action { $Global:DPCEventArgs = $EventArgs }
	}
	process {
		Write-Progress -Activity 'Downloading file' -Status $url
		$client.DownloadFileAsync($url, $localFile)
		
		while (!($Global:downloadComplete)) {
			$pc = $Global:DPCEventArgs.ProgressPercentage
			if ($pc -ne $null) {
				Write-Progress -Activity 'Downloading file' -Status $url -PercentComplete $pc
			}
		}
		Write-Progress -Activity 'Downloading file' -Status $url -Complete
	}

	end {
		Unregister-Event -SourceIdentifier WebClient.DownloadProgressChanged
		Unregister-Event -SourceIdentifier WebClient.DownloadFileComplete
		$client.Dispose()
		$Global:downloadComplete = $null
		$Global:DPCEventArgs = $null
		Remove-Variable client
		Remove-Variable eventDataComplete
		Remove-Variable eventDataProgress
		[GC]::Collect()
	} 
}

function Update-Environment {   
    $locations = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
                 'HKCU:\Environment'

    $locations | ForEach-Object {   
        $k = Get-Item $_
        $k.GetValueNames() | ForEach-Object {
            $name  = $_
            $value = $k.GetValue($_)
            Set-Item -Path Env:\$name -Value $value
        }
    }
}

$strDownloadDir = "$env:Temp\DevSalt"
New-Item $strDownloadDir -Type Directory -Force

Clear-Host
Write-Host "Python 2.7 (entire package)"
$url = "https://www.python.org/ftp/python/2.7.8/python-2.7.8.amd64.msi"
$file = "$strDownloadDir\python-2.7.8.amd64.msi"
DownloadFileWithProgress $url $file
Write-Host "Installing..."
$p = Start-Process msiexec -ArgumentList "/i $file /qb ADDLOCAL=ALL" -Wait -NoNewWindow -PassThru
Write-Host "Refreshing the Environment Variables..."

$path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
[System.Environment]::SetEnvironmentVariable("Path", "C:\Python27\Scripts;$path", "Machine")

Update-Environment

Clear-Host
Write-Host "Microsoft Visual C++ Compiler for Python (this may take a while)"
$url = "http://download.microsoft.com/download/7/9/6/796EF2E4-801B-4FC4-AB28-B59FBF6D907B/VCForPython27.msi"
$file = "$strDownloadDir\VCForPython27.msi"
DownloadFileWithProgress $url $file
Write-Host "Installing..."
$p = Start-Process msiexec -ArgumentList "/i $file /qb" -Wait -NoNewWindow -PassThru

Clear-Host
Write-Host "Microsoft Visual C++ 2008 Redistributable"
$url = "http://download.microsoft.com/download/d/2/4/d242c3fb-da5a-4542-ad66-f9661d0a8d19/vcredist_x64.exe"
$file = "$strDownloadDir\vcredist_x64.exe"
DownloadFileWithProgress $url $file
Write-Host "Installing..."
$p = Start-Process $file -ArgumentList "/q" -Wait -NoNewWindow -PassThru

Clear-Host
Write-Host "Microsoft Visual C++ 2008 MFC Security Update Redistributable"
$url = "http://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x64.exe"
$file = "$strDownloadDir\vcredist_x64.exe"
DownloadFileWithProgress $url $file
Write-Host "Installing..."
$p = Start-Process $file -ArgumentList "/q" -Wait -NoNewWindow -PassThru

Write-Host "copying library file to c:\python27"
$file = "C:\Windows\WinSxS\amd64_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.6161_none_08e61857a83bc251\msvcp90.dll"
Copy-Item $file C:\Python27

Clear-Host
Write-Host "Open SSL for Windows (Light)"
$url = "http://slproweb.com/download/Win64OpenSSL_Light-1_0_1L.exe"
$file = "$strDownloadDir\Win64OpenSSL_Light-1_0_1L.exe"
DownloadFileWithProgress $url $file
Write-Host "Installing..."
$p = Start-Process $file -ArgumentList "/silent" -Wait -NoNewWindow -PassThru

Clear-Host
Write-Host "M2Crypto"
$url = "http://chandlerproject.org/pub/Projects/MeTooCrypto/M2Crypto-0.21.1.win-amd64-py2.7.exe"
$file = "$strDownloadDir\M2Crypto-0.21.1.win-amd64-py2.7.exe"
DownloadFileWithProgress $url $file
Write-Host "Installing..."
$p = Start-Process $file -Wait -NoNewWindow -PassThru

Clear-Host
Write-Host "pywin32"
$url = "http://sourceforge.net/projects/pywin32/files/pywin32/Build%20219/pywin32-219.win-amd64-py2.7.exe"
$file = "$strDownloadDir\pywin32-219.win-amd64-py2.7.exe"
DownloadFileWithProgress $url $file
Write-Host "Installing..."
$p = Start-Process $file -Wait -NoNewWindow -PassThru

Clear-Host
Write-Host "make"
$url = "ftp://ftp.equation.com/make/64/make.exe"
$file = "$strDownloadDir\make.exe"
DownloadFileWithProgress $url $file
Write-Host "Copying to Python27 directory..."
Copy-Item $file C:\Python27

Clear-Host
Write-Host "pefile"
$url = "https://pefile.googlecode.com/files/pefile-1.2.10-139.zip"
$file = "$strDownloadDir\pefile-1.2.10-139.zip"
DownloadFileWithProgress $url $file
Write-Host "Unzipping..."
$shell = New-Object -ComObject Shell.Application
$item = $shell.NameSpace("$file\pefile-1.2.10-139")
$path = Split-Path (Join-Path $strDownloadDir "pefile-1.2.10-139")
if (!(Test-Path $path)) {$null = mkdir $path}
$shell.NameSpace($path).CopyHere($item)
Write-Host "Installing..."
cd $strDownloadDir\pefile-1.2.10-139
$p = Start-Process python -ArgumentList "setup.py install" -Wait -NoNewWindow -PassThru

Clear-Host
Write-Host "easy_install"
$url = "https://bootstrap.pypa.io/ez_setup.py"
$file = "$strDownloadDir\ez_setup.py"
DownloadFileWithProgress $url $file
Write-Host "Copying to Python27 directory..."
Copy-Item $file C:\Python27

Write-Host "Setting up the environment"
Set-Location -Path C:\Python27
$p = Start-Process python -ArgumentList "ez_setup.py" -Wait -NoNewWindow -PassThru
$p = Start-Process easy_install -ArgumentList "pip" -Wait -NoNewWindow -PassThru
$p = Start-Process pip -ArgumentList "install pycrypto" -Wait -NoNewWindow -PassThru
$p = Start-Process pip -ArgumentList "install cython" -Wait -NoNewWindow -PassThru
$p = Start-Process pip -ArgumentList "install jinja2" -Wait -NoNewWindow -PassThru
$p = Start-Process pip -ArgumentList "install msgpack-python" -Wait -NoNewWindow -PassThru
$p = Start-Process pip -ArgumentList "install psutil" -Wait -NoNewWindow -PassThru
$p = Start-Process pip -ArgumentList "install pyyaml" -Wait -NoNewWindow -PassThru
$p = Start-Process easy_install -ArgumentList "pyzmq==13.1.0" -Wait -NoNewWindow -PassThru
$file = "C:\Python27\Lib\site-packages\pyzmq-13.1.0-py2.7-win-amd64.egg\zmq\libzmq.pyd"
Copy-Item $file C:\Python27
$p = Start-Process pip -ArgumentList "install wmi" -Wait -NoNewWindow -PassThru
$p = Start-Process pip -ArgumentList "install requests" -Wait -NoNewWindow -PassThru
$p = Start-Process pip -ArgumentList "install six" -Wait -NoNewWindow -PassThru
$p = Start-Process pip -ArgumentList "install certifi" -Wait -NoNewWindow -PassThru
$p = Start-Process pip -ArgumentList "install esky" -Wait -NoNewWindow -PassThru
$p = Start-Process easy_install -ArgumentList "bbfreeze" -Wait -NoNewWindow -PassThru
$p = Start-Process pip -ArgumentList "install sphinx==1.3b2" -Wait -NoNewWindow -PassThru

Write-Host "Cleaning up downloaded files"
Remove-Item $strDownloadDir -Force -Recurse

Write-Host "Salt Stack Dev Environment Script Complete"