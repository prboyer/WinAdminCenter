<#
    Script to enable SSO from WAC to endpoints. 
    Paul B - 7-20-2020

    See for more information: https://charbelnemnom.com/2019/07/how-to-enable-single-sign-on-sso-for-windows-admin-center/

#>

### Variables ###
$WAC = Get-ADComputer -Identity "winadmin";

[int]$errorFlag = 1;
#################
# Import AD Module
try{
	Import-Module ActiveDirectory
}
catch{

    # If not installed and available for import, then install module
	Start-Process "Powershell.exe" -ArgumentsList "-executionpolicy bypass -command {
		Add-WindowsCapability –online –Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"
	}" -Wait -NoNewWindow;

	Import-Module ActiveDirectory
}

# Set Delegation access on current machine
try{
    Get-ADComputer -Identity $env:COMPUTERNAME | Set-ADComputer -PrincipalsAllowedToDelegateToAccount $WAC -Verbose
}
catch{
    $errorFlag = -1;
}

# Clear the KDC Cache
try {
    Start-Process "cmd.exe" -ArgumentList "/c klist purge -li 0x3e7" -Wait -NoNewWindow 
}
catch {
    $errorFlag = -2;
}

# Create registry key to confirm installaton
New-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE"-Name "SSCC" -ItemType key -ErrorAction SilentlyContinue
New-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\SSCC" -Name "WAC" -ItemType key -ErrorAction SilentlyContinue
New-ItemProperty -Name "Installed" -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\SSCC\WAC" -Value $errorFlag -PropertyType String -Force