function Set-WACDelegatedCredentials {
    <#
    .SYNOPSIS
    Script to enable SSO from WAC to endpoints
    
    .DESCRIPTION
    The script enables SSO by setting delegation in AD and clearing cache. Then sets registry keys to indicate that SSO has been enabled.
    
    .PARAMETER Gateway
    String name of the Gateway endpoint
    
    .EXAMPLE
    Set-WACDelegatedCredentials -Gateway Server01

    .LINK
    https://charbelnemnom.com/2019/07/how-to-enable-single-sign-on-sso-for-windows-admin-center/
    
    .NOTES
        Author: Paul Boyer
        Date: 7-20-2020
    #>
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Gateway,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]
        $LogPath
    )
    # Commented the Requires statement out so that dynamic checking can be performed below
    <# #Requires -Module  ActiveDirectory #>

    <# Variables #>
            # Windows Admin Center gateway represented as an AD Object
            [Microsoft.ActiveDirectory.Management.ADComputer]$WAC = Get-ADComputer -Identity $Gateway;

            # Variable to store Error information
            [String]$E = "";

            # Error Flag to determine if the install completed sucessfully. 1=error, 0=no errors
            [Int]$ErrorFlag = 2;

    # Determine if the ActiveDirectory module is installed and available for import
        if("ActiveDirectory" -iin [String[]]@((Get-Module -ListAvailable | Select-Object Name).Name)){
            try{
                Import-Module ActiveDirectory
            }
            catch{
                Write-Error "Unable to Import ActiveDirectory Module" -ErrorAction Stop -ErrorVariable +E
            }
        }else{
                Add-WindowsCapability -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0" -Online -Verbose -ErrorAction Stop -ErrorVariable +E
                Import-Module ActiveDirectory
        }

        try{
            # Set Delegation access on current machine
            Get-ADComputer -Identity $env:COMPUTERNAME | Set-ADComputer -PrincipalsAllowedToDelegateToAccount $WAC -Verbose -ErrorAction Stop -ErrorVariable +E

            # Clear the KDC Cache
            Start-Process "cmd.exe" -ArgumentList "/c klist purge -li 0x3e7" -Wait -NoNewWindow -ErrorAction Continue -ErrorVariable +E
            
            # Set the error flag
            $ErrorFlag = 0;

        }catch{
            $ErrorFlag = 1;
            Write-Error $ERROR -ErrorVariable +E
        }

        # Create registry key to confirm installaton
        New-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE"-Name "SSCC" -ItemType key -ErrorAction SilentlyContinue -ErrorVariable +E
        New-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\SSCC" -Name "WAC" -ItemType key -ErrorAction SilentlyContinue -ErrorVariable +E
        New-ItemProperty -Name "DelegatedCreds" -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\SSCC\WAC" -Value $ErrorFlag -PropertyType DWord -Force -ErrorAction Stop -ErrorVariable +E

        # Handle the error log output. Only write an error log if errors are logged to $E
        if ($E -ne "") {
            if ($LogPath -ne "") {
                $E | Out-File -FilePath $LogPath -Force
            }else{
                $E | Out-File -FilePath $PSScriptRoot\WAC_DelegatedCredsErrorLog.txt -Force
            }
        }        
}