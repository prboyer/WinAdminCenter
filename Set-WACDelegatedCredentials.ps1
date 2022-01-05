function Set-WACDelegatedCredentials {
    <#
    .SYNOPSIS
    Script to enable SSO from Windows Admin Center to endpoints
    
    .DESCRIPTION
    The script enables SSO by setting delegation in AD and clearing the Kerberos cache. Then sets registry keys to indicate that SSO has been enabled.

    .PARAMETER ConfigFile
    A mandatory parameter that specifies the path to the JSON configuration file.
    
    .PARAMETER GatewayURI
    An override parameter that specifies the URI of Gateway endpoint. The value from the JSON configuration file will be ignored if this parameter is specified.

    .PARAMETER LogPath
    An override parameter that specifies the path to the log file. The value from the JSON configuration file will be ignored if this parameter is specified.
    
    .EXAMPLE
    Set-WACDelegatedCredentials -ConfigFile "C:\Temp\Config.json"

    .EXAMPLE
    Set-WACDelegatedCredentials -ConfigFile "C:\Temp\Config.json" -GatewayURI "https://gateway.contoso.com"

    .LINK
    https://charbelnemnom.com/2019/07/how-to-enable-single-sign-on-sso-for-windows-admin-center/
    
    .NOTES
        Author: Paul Boyer
        Date: 7-20-2020
    #>
    param (
        [Parameter(Mandatory=$true)]
        [ValidateScript({
            # Check that a path to a JSON file was passed
            if([IO.Path]::getExtension($_) -eq ".json"){
                $true
            }else{
                $false
            }
        })]
        [String]
        $ConfigFile,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]
        $GatewayURI,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]
        $LogPath
    )
    # Commented the Requires statement out so that dynamic checking can be performed below
    <# #Requires -Module  ActiveDirectory #>

    # Import settigns from the config file
    [Object[]]$CONFIG = Get-Content -Raw -Path $ConfigFile | ConvertFrom-Json

    <# Variables #>
        # Windows Admin Center gateway URL
        [String]$GATEWAY;
        if ($GatewayURI -ne ""){
            $GATEWAY = $GatewayURI
        }else{
            $GATEWAY = $CONFIG.DelegatedCredentials.Gateway
        }

        # Windows Admin Center gateway represented as an AD Object
        [Microsoft.ActiveDirectory.Management.ADComputer]$WAC = Get-ADComputer -Identity $GATEWAY;

        # Variable to store Error information
        [String]$global:E = "";

        # Error Flag to determine if the install completed successfully. 1=error, 0=no errors. -2 is the initial value. 
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

        # Create registry key to confirm installatio
        New-Item -Path "Registry::$($CONFIG.DelegatedCredentials.Registry.Hive)\$($CONFIG.DelegatedCredentials.Registry.Path)"-Name $CONFIG.DelegatedCredentials.Registry.Key -ItemType Key -Force -ErrorAction SilentlyContinue -ErrorVariable +E
        New-ItemProperty -Path "Registry::$($CONFIG.DelegatedCredentials.Registry.Hive)\$($CONFIG.DelegatedCredentials.Registry.Path)\$($CONFIG.DelegatedCredentials.Registry.Key)" -Name $CONFIG.DelegatedCredentials.Registry.PropertyName -PropertyType DWord -Value $ErrorFlag -Force -ErrorAction Stop -ErrorVariable +E

        # Handle the error log output. Only write an error log if errors are logged to $E
        if ($E -ne "") {
            # First determine the path of where to write the log
            [String]$LogFilePath
            if ($LogPath -ne "") {
                $LogFilePath = $LogPath
            }else{
                $LogFilePath = $CONFIG.DelegatedCredentials.Logs.LogPath
            }

            # Write out the error log to the specified path
            $E | Out-File -FilePath "$LogFilePath\WindowsAdminCenter_DelegatedCredentials_$(Get-Date -Format FileDateTime).txt" -Force
        }        
}