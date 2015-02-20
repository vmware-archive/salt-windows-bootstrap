# Set-ExecutionPolicy RemoteSigned

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

$strWindowsRepo = "http://docs.saltstack.com/downloads/windows-deps"

Clear-Host
Write-Host "Python 2.7 (entire package)"
$file = "python-2.7.8.amd64.msi"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
DownloadFileWithProgress $url $file
Write-Host "Installing..."
$p = Start-Process msiexec -ArgumentList "/i $file /qb ADDLOCAL=ALL" -Wait -NoNewWindow -PassThru
Write-Host "Refreshing the Environment Variables..."

$path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
[System.Environment]::SetEnvironmentVariable("Path", "C:\Python27;C:\Python27\Scripts;$path", "Machine")

Update-Environment

Clear-Host
Write-Host "Microsoft Visual C++ Compiler for Python (this may take a while)"
$file = "VCForPython27.msi"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
DownloadFileWithProgress $url $file
Write-Host "Installing..."
$p = Start-Process msiexec -ArgumentList "/i $file /qb" -Wait -NoNewWindow -PassThru

Clear-Host
Write-Host "Microsoft Visual C++ 2008 Redistributable"
$file = "vcredist_x64.exe"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
DownloadFileWithProgress $url $file
Write-Host "Installing..."
$p = Start-Process $file -ArgumentList "/q" -Wait -NoNewWindow -PassThru

Clear-Host
Write-Host "Microsoft Visual C++ 2008 MFC Security Update Redistributable"
$file = "vcredist_x64_mfc_update.exe"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
DownloadFileWithProgress $url $file
Write-Host "Installing..."
$p = Start-Process $file -ArgumentList "/q" -Wait -NoNewWindow -PassThru

Write-Host "copying library file to c:\python27"
$file = "C:\Windows\WinSxS\amd64_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.6161_none_08e61857a83bc251\msvcp90.dll"
Copy-Item $file C:\Python27

Clear-Host
Write-Host "Open SSL for Windows (Light)"
$file = "Win64OpenSSL_Light-1_0_1L.exe"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
DownloadFileWithProgress $url $file
Write-Host "Installing..."
$p = Start-Process $file -ArgumentList "/silent" -Wait -NoNewWindow -PassThru

Clear-Host
Write-Host "M2Crypto"
$file = "M2Crypto-0.21.1.win-amd64-py2.7.exe"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
DownloadFileWithProgress $url $file
Write-Host "Installing..."
$p = Start-Process $file -Wait -NoNewWindow -PassThru

Clear-Host
Write-Host "pywin32"
$file = "pywin32-219.win-amd64-py2.7.exe"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
DownloadFileWithProgress $url $file
Write-Host "Installing..."
$p = Start-Process $file -Wait -NoNewWindow -PassThru

Clear-Host
Write-Host "make"
$file = "make.exe"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
DownloadFileWithProgress $url $file
Write-Host "Copying to Python27 directory..."
Copy-Item $file C:\Python27

Clear-Host
Write-Host "pefile"
$file = "pefile-1.2.10-139.zip"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
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
$file = "ez_setup.py"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
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