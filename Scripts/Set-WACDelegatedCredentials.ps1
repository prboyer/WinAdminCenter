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
        [String]
        $Gateway
    )
    #Requires -Module  ActiveDirectory

    <# Variables #>
        # Windows Admin Center gateway represented as an AD Object
        [Microsoft.ActiveDirectory.Management.ADComputer]$WAC = Get-ADComputer -Identity $Gateway;

        # Variable to store Error information
        [String]$ERROR

    try{
        # Set Delegation access on current machine
        Get-ADComputer -Identity $env:COMPUTERNAME | Set-ADComputer -PrincipalsAllowedToDelegateToAccount $WAC -Verbose

        # Clear the KDC Cache
        Start-Process "cmd.exe" -ArgumentList "/c klist purge -li 0x3e7" -Wait -NoNewWindow 

    }catch{
        Write-Error $ERROR -ErrorVariable +ERROR
    }

    # Create registry key to confirm installaton
    New-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE"-Name "SSCC" -ItemType key -ErrorAction SilentlyContinue
    New-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\SSCC" -Name "WAC" -ItemType key -ErrorAction SilentlyContinue
    New-ItemProperty -Name "Installed" -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\SSCC\WAC" -Value $errorFlag -PropertyType String -Force
}

Set-WACDelegatedCredentials -Gateway "Winadmin"