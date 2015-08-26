#======================================================================================================================
# You may need to change the execution policy in order to run this script
# Run the following in powershell:
#
# Set-ExecutionPolicy RemoteSigned
#
#======================================================================================================================
#
#          FILE: Bootstrap.ps1
#
#   DESCRIPTION: Bootstrap salt installation for 64bit windows distributions
#
#          BUGS: https://github.com/saltstack/salt-windows-bootstrap/issues
#
#     COPYRIGHT: (c) 2012-2015 by the SaltStack Team, see AUTHORS.rst for more
#                details.
#
#       LICENSE: Apache 2.0
#  ORGANIZATION: SaltStack (saltstack.org)
#       CREATED: 02/09/2015
#======================================================================================================================

# Declare Variables
#--------------------------------------------------------
$strDownloadDir    = "$env:Temp\DevSalt"
$strDevelopmentDir = "C:\Salt-Dev"
$strSaltDir        = "C:\salt"
$strWindowsRepo    = "https://repo.saltstack.com/windows/dependencies/"
$strSaltBranch     = "develop"

# Create Directories
#--------------------------------------------------------
New-Item $strDownloadDir -ItemType Directory -Force
New-Item $strDevelopmentDir -ItemType Directory -Force
New-Item $strSaltDir -ItemType Directory -Force

#========================================================
# Define Functions
#========================================================
Function DownloadFileWithProgress {

    # Code for this function borrowed from http://poshcode.org/2461
    # Thanks Crazy Dave

    # This function downloads the passed file and shows a progress bar
    # It receives two parameters:
    #    $url - the file source
    #    $localfile - the file destination on the local machine

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
    
    # This function updates the environment variables
    # It is called after installing git and python so that they can be used later in the script

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

#========================================================
# Download Prerequisite Files
#========================================================

Clear-Host
#--------------------------------------------------------
# Git
#--------------------------------------------------------

# Not necessarily a prerequisite, but needed to pull salt

# Create the inf file to be passed to the Git executable
Write-Host "Git for Windows"
Write-Host "- creating inf"
Set-Content -path $strDownloadDir\git.inf -value "[Setup]"
Add-Content -path $strDownloadDir\git.inf -value "Lang=default"
Add-Content -path $strDownloadDir\git.inf -value "Dir=C:\Program Files (x86)\Git"
Add-Content -path $strDownloadDir\git.inf -value "Group=Git"
Add-Content -path $strDownloadDir\git.inf -value "NoIcons=0"
Add-Content -path $strDownloadDir\git.inf -value "SetupType=default"
Add-Content -path $strDownloadDir\git.inf -value "Components=ext,ext\cheetah,assoc,assoc_sh"
Add-Content -path $strDownloadDir\git.inf -value "Tasks="
Add-Content -path $strDownloadDir\git.inf -value "PathOption=Cmd"
Add-Content -path $strDownloadDir\git.inf -value "SSHOption=OpenSSH"
Add-Content -path $strDownloadDir\git.inf -value "CRLFOption=CRLFAlways"

# Download the file
Write-Host "- downloading file"
$file = "Git-1.9.5-preview20141217.exe"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
DownloadFileWithProgress $url $file

# Install the file silently
Write-Host "Installing..."
$p = Start-Process $file -ArgumentList '/SILENT /LOADINF="$strDownloadDir\git.inf"' -Wait -NoNewWindow -PassThru

Clear-Host
#--------------------------------------------------------
# Python 2.7
#--------------------------------------------------------

# There are problems with 2.7.9, so we're using 2.7.8

# Download the file
Write-Host "Python 2.7 (entire package)"
$file = "python-2.7.8.amd64.msi"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
DownloadFileWithProgress $url $file

# Install the file
Write-Host "Installing..."
$p = Start-Process msiexec -ArgumentList "/i $file /qb ADDLOCAL=ALL" -Wait -NoNewWindow -PassThru
Write-Host "Refreshing the Environment Variables..."

#--------------------------------------------------------
# Update Environment Varibales
#--------------------------------------------------------
$path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
[System.Environment]::SetEnvironmentVariable("Path", "C:\Program Files (x86)\Git\cmd;C:\Python27;C:\Python27\Scripts;$path", "Machine")

Update-Environment

Clear-Host
#--------------------------------------------------------
# VC++ Compiler for Python
#--------------------------------------------------------

# Download the file
Write-Host "Microsoft Visual C++ Compiler for Python (this may take a while)"
$file = "VCForPython27.msi"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
DownloadFileWithProgress $url $file

# Install the file
Write-Host "Installing..."
$p = Start-Process msiexec -ArgumentList "/i $file /qb" -Wait -NoNewWindow -PassThru

Clear-Host
#--------------------------------------------------------
# Visual C++ 2008 Redistributable
#--------------------------------------------------------

# Even though we're installing the patch later, OpenSSL requires this

# Download file
Write-Host "Microsoft Visual C++ 2008 Redistributable"
$file = "vcredist_x64.exe"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
DownloadFileWithProgress $url $file

# Install file
Write-Host "Installing..."
$p = Start-Process $file -ArgumentList "/q" -Wait -NoNewWindow -PassThru

Clear-Host
#--------------------------------------------------------
# Visual C++ 2008 Redistrubutable
#--------------------------------------------------------

# Download File
Write-Host "Microsoft Visual C++ 2008 MFC Security Update Redistributable"
$file = "vcredist_x64_mfc_update.exe"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
DownloadFileWithProgress $url $file

# Install File
Write-Host "Installing..."
$p = Start-Process $file -ArgumentList "/q" -Wait -NoNewWindow -PassThru

# Copy the libary to the Python directory (for compiling)
Write-Host "copying library file to c:\python27"
$file = "C:\Windows\WinSxS\amd64_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.6161_none_08e61857a83bc251\msvcp90.dll"
Copy-Item $file C:\Python27 -Force

Clear-Host
#--------------------------------------------------------
# OpenSSL
#--------------------------------------------------------

# Download file
Write-Host "Open SSL for Windows (Light)"
$file = "Win64OpenSSL_Light-1_0_1L.exe"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
DownloadFileWithProgress $url $file

# Install file
Write-Host "Installing..."
$p = Start-Process $file -ArgumentList "/silent" -Wait -NoNewWindow -PassThru

Clear-Host
#--------------------------------------------------------
# M2Crypto
#--------------------------------------------------------

# Couldn't find a version of this I could install silently
# Install created with distutils which has no silent option

# Download file
Write-Host "M2Crypto"
$file = "M2Crypto-0.21.1.win-amd64-py2.7.exe"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
DownloadFileWithProgress $url $file

# Install file (requires the user to click through it)
Write-Host "Installing..."
$p = Start-Process $file -Wait -NoNewWindow -PassThru

Clear-Host
#--------------------------------------------------------
# PyWin32
#--------------------------------------------------------

# Again, couldn't find a version that could install silently
# Install created with distutils which has no silent option

# Download file
Write-Host "pywin32"
$file = "pywin32-219.win-amd64-py2.7.exe"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
DownloadFileWithProgress $url $file

# Install file
Write-Host "Installing..."
$p = Start-Process $file -Wait -NoNewWindow -PassThru

Clear-Host
#--------------------------------------------------------
# Make
#--------------------------------------------------------

# Download file
Write-Host "make"
$file = "make.exe"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
DownloadFileWithProgress $url $file

# Copy to the python directory
Write-Host "Copying to Python27 directory..."
Copy-Item $file C:\Python27 -Force

Clear-Host
#--------------------------------------------------------
# pefile
#--------------------------------------------------------

# Download file
Write-Host "pefile"
$file = "pefile-1.2.10-139.zip"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
DownloadFileWithProgress $url $file

# Unzip the package
Write-Host "Unzipping..."
$shell = New-Object -ComObject Shell.Application
$item = $shell.NameSpace("$file\pefile-1.2.10-139")
$path = Split-Path (Join-Path $strDownloadDir "pefile-1.2.10-139")
if (!(Test-Path $path)) {$null = mkdir $path}
$shell.NameSpace($path).CopyHere($item)
Write-Host "Installing..."

# Install the package
Set-Location -Path $strDownloadDir\pefile-1.2.10-139
$p = Start-Process python -ArgumentList "setup.py install" -Wait -NoNewWindow -PassThru

Clear-Host
#--------------------------------------------------------
# easy_install
#--------------------------------------------------------

# This was installed with python 2.7.9
# Now that we're using python 2.7.8, we have to install it

# Download file
Write-Host "easy_install"
$file = "ez_setup.py"
$url = "$strWindowsRepo\$file"
$file = "$strDownloadDir\$file"
DownloadFileWithProgress $url $file

# Copy to the python directory
Write-Host "Copying to Python27 directory..."
Copy-Item $file C:\Python27 -Force

#========================================================
# Clone the Salt Repository
#========================================================

# This needs to be done here in order for the config file copy to be successful
# For some reason it failed if you tried to copy the config right after the clone

# Clone Salet
Write-Host "Cloning the SaltStack Git Repository"
Set-Location -Path "$strDevelopmentDir"
$p = Start-Process git -ArgumentList "clone https://github.com/saltstack/salt" -Wait -NoNewWindow -PassThru

# Checkout the branch
Set-Location -Path "$strDevelopmentDir\Salt"
$p = Start-Process git -ArgumentList "checkout $strSaltBranch" -Wait -NoNewWindow -PassThru

#=======================================================
# Install additional prerequisites
#=======================================================

# install prerequisites using ez_insatll and pip
# Pip has a hard time compiling some of the binaries
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
Copy-Item $file C:\Python27 -Force
$p = Start-Process pip -ArgumentList "install wmi" -Wait -NoNewWindow -PassThru
$p = Start-Process pip -ArgumentList "install requests" -Wait -NoNewWindow -PassThru
$p = Start-Process pip -ArgumentList "install six" -Wait -NoNewWindow -PassThru
$p = Start-Process pip -ArgumentList "install certifi" -Wait -NoNewWindow -PassThru
$p = Start-Process pip -ArgumentList "install esky" -Wait -NoNewWindow -PassThru
$p = Start-Process easy_install -ArgumentList "bbfreeze" -Wait -NoNewWindow -PassThru
$p = Start-Process pip -ArgumentList "install sphinx==1.3b2" -Wait -NoNewWindow -PassThru

#--------------------------------------------------------
# Install Salt
#--------------------------------------------------------
Set-Location -Path "$strDevelopmentDir\salt"
Start-Process python -ArgumentList "setup.py install --force" -Wait -NoNewWindow -PassThru

#--------------------------------------------------------
# Remove the temperary download directory
#--------------------------------------------------------
Write-Host "Cleaning up downloaded files"
Remove-Item $strDownloadDir -Force -Recurse

#--------------------------------------------------------
# Copy salt config files to salt directory
#--------------------------------------------------------
Write-Host "Copying Salt Config Files..."
$strConfigFiles = "$strDevelopmentDir\salt\pkg\windows\buildenv"
Copy-Item $strConfigFiles\* $strSaltDir -Recurse -Force

#--------------------------------------------------------
# Script complete
#--------------------------------------------------------
Write-Host "Salt Stack Dev Environment Script Complete"
Write-Host "Press any key to continue ..."
$HOST.UI.RawUI.Flushinputbuffer()
$HOST.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
