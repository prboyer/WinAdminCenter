function Import-WACConnections {
    <#
    .SYNOPSIS
    Script for importing Computers and Servers into Windows Admin Center

    .DESCRIPTION
    The script will import computers and servers into Windows Admin Center as global connections that all users can utilize. It reads in settings from a JSON configuration file, and then generates a CSV file that can be imported into WAC.
    
    .PARAMETER GatewayURL
    An override parameter for the gateway URL. If not specified, the script will attempt to determine the gateway URL from the configuration file.
    
    .PARAMETER CSVPath
    An override parameter for the location to save the CSV file. If not specified, the script will attempt to determine the location from the configuration file.
    
    .PARAMETER LogPath
    An override parameter for the location to save the log file. If not specified, the script will attempt to determine the location from the configuration file.
    
    .PARAMETER ConfigFile
    Path to the JSON configuration file. If not specified, the script will fail to continue execution.
    
    .PARAMETER ComputersCustomMatching
    An override parameter that tells the script to ignore the default tagging algorithm for computers and instead use the custom matching algorithm. It will not use the tags defined in the JSON file and will instead rely on the tags defined in the custom section of the script.
    
    .PARAMETER ServersCustomMatching
    An override parameter that tells the script to ignore the default tagging algorithm for servers and instead use the custom matching algorithm. It will not use the tags defined in the JSON file and will instead rely on the tags defined in the custom section of the script.
    
    .PARAMETER Quiet
    A switch parameter that sets the InformationPreference to SilentlyContinue. This will limit the standard output of the script.
    
    .EXAMPLE
    Import-WACConnections -GatewayURL "http://localhost:8080" -CSVPath "C:\Temp\Connections.csv" -ConfigFile "C:\Temp\Config.json"

    In this example, the script will ignore the gateway URL from the configuration file, and instead use the one specified by the -Gateway parameter. Similarly, the CSV file will be saved to the C:\Temp directory, rather than the location specified in the configuration file. Other parameters in the configuration file will be applied.

    .EXAMPLE
    Import-WACConnections -ConfigFile "C:\Temp\Config.json"

    The script will use all values from the configuration file.
    
    .LINK
    https://docs.microsoft.com/en-us/windows-server/manage/windows-admin-center/configure/use-powershell

    .NOTES
        Author: Paul Boyer
        Date: 01-05-2022
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
        [String]
        $GatewayURL,
        [Parameter()]
        [String]
        $CSVPath,
        [Parameter()]
        [String]
        $LogPath,
        [Parameter(Mandatory=$false, ParameterSetName="CustomMatching")]
        [Switch]
        $ComputersCustomMatching,
        [Parameter(Mandatory=$false, ParameterSetName="CustomMatching")]
        [Switch]
        $ServersCustomMatching,
        [Parameter()]
        [Switch]
        $Quiet

    )
    #Requires -Module ActiveDirectory
    
    # Set script verbosity by setting the $InformationPreference variable
    if($Quiet){
        $InformationPreference = "SilentlyContinue"
    }else{
        $InformationPreference = "Continue"
    }

    # Import required modules
        Import-Module "$env:ProgramFiles\Windows Admin Center\PowerShell\Modules\ConnectionTools\ConnectionTools.psm1"
    
        <# CONSTANTS #>
        # Variable to store the contents of the JSON config file
        try{
            [Object]$CONFIG = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
        }catch{
            Write-Error "Unable to load config file." -ErrorAction Stop -ErrorVariable +INFO
        }

        # Constant string type for windows 10 PCs
        [String]$WIN_PC = "msft.sme.connection-type.windows-client"

        # Constant string type for windows servers
        [String]$WIN_SERVER = "msft.sme.connection-type.server"

        # Constant for storing the Gateway URL
        [String]$GATEWAY;
        if($GatewayURL -eq ""){
            $GATEWAY = $CONFIG.Connections.Gateway
        }else{
            $GATEWAY = $GatewayURL
        }

        # Variable to hold log information
        [String]$INFO

    <# AD DS SearchBases #>
        # Computer Configuration
        [String[]]$Computer_SearchBaseList = $CONFIG.Connections.Computers.SearchBases.SearchBase

        # Server Configuration
        [String[]]$Server_SearchBaseList = $CONFIG.Connections.Servers.SearchBases.SearchBase

    Write-Information $("{0} ******** Begin Logging *******" -f $(Get-Date -Format "G")) -InformationVariable +INFO

    <# Discover Computers to import into WAC #>
        Write-Information $("{0}`tBegin importing Computers into Windows Admin Center ({1})" -f $(Get-Date -Format "G"),$GATEWAY.ToUpper()) -InformationVariable +INFO

        # Tags to apply to all imported computers
        [String[]]$Computer_Tags = $CONFIG.Connections.Computers.DefaultTags

        # Array list to hold Computer objects
        [System.Collections.ArrayList]$Computers = @(); 

        # Parse through the SearchBase list for computer objects
        foreach($s in $Computer_SearchBaseList){
            Get-ADComputer -Filter * -Properties DistinguishedName,CanonicalName -SearchBase $s | ForEach-Object{
                # Clear tagging for each iteration through the loop. Then add back in necessary tags
                [String[]]$private:Tags = $null;

                # Apply the default computer tags
                $Tags += $Computer_Tags;

                if($ComputersCustomMatching){
                    <# CUSTOM MATCHING FOR COMPUTER OBJECTS #>
                    <# Enter custom matching logic in this section #>
                    


                    <# End of custom matching section. Do not modify code outside this section.#>
                }else{
                    # Apply the tags correlated to the SearchBase
                    $Tags += ($CONFIG.Connections.Computers.SearchBases | Where-Object{$_.SearchBase -eq $s}).Tags;
                }

                #Add computers to an array list as custom objects
                $Computers.Add(
                    [PSCustomObject]@{
                        name = $_.DNSHostname
                        type = $WIN_PC
                        tags = $($Tags -join '|');
                        groupId = "global"
                    } 
                ) | ForEach-Object {
                    Write-Information $("{0}`t`tDiscovered PC {1}" -f $(Get-Date -Format "G"),$Computers[$_].name) -InformationVariable +INFO
                }
            }
        }

    <# Discover Servers to import into WAC #>
        Write-Information $("{0}`tBegin importing Servers into Windows Admin Center ({1})" -f $(Get-Date -Format "G"),$GATEWAY.ToUpper()) -InformationVariable +INFO

        # Tags to apply to all imported servers
        [String[]]$Server_Tags = $CONFIG.Connections.Servers.DefaultTags

        # Array list to hold all Server objects
        [System.Collections.ArrayList]$Servers = @();

        foreach($s in $Server_SearchBaseList){
            Get-ADComputer -Filter * -Properties DistinguishedName -SearchBase $s | ForEach-Object {
    
                # Clear tagging for each iteration through the loop. Then add back in necessary tags
                [String[]]$private:Tags = $null;

                # Apply the default server tags
                $Tags += $Server_Tags;

                if(-not $ServersCustomMatching){
                    # Apply the tags correlated to the SearchBase
                    $Tags += ($CONFIG.Connections.Servers.SearchBases | Where-Object{$_.SearchBase -eq $s}).Tags;
                }else{
                    <# CUSTOM MATCHING FOR SERVER OBJECTS #>
                    <# Enter custom matching logic in this section #>
                    


                    <# End of custom matching section. Do not modify code outside this section.#>
                }else{
                    # Apply the tags correlated to the SearchBase
                    $Tags += ($CONFIG.Connections.Servers.SearchBases | Where-Object{$_.SearchBase -eq $s}).Tags;
                }

                #Add computers to an array list as custom objects
                $Servers.Add(
                    [PSCustomObject]@{
                        name = $_.DNSHostname
                        type = $WIN_SERVER
                        tags = $($Tags -join '|');
                        groupId = "global"
                    } 
                ) | ForEach-Object {
                    Write-Information $("{0}`t`tDiscovered Server {1}" -f $(Get-Date -Format "G"),$Servers[$_].name) -InformationVariable +INFO
                }
            }
        }
    
    <# Generate a CSV file for importing into WAC #>
        # Resolve the $CSVPath location. Check if a path was passed at runtime or if the path in the configuration file should be used.
        if ($CSVPath -eq ""){
            $CSVPath = $CONFIG.Connections.CSV.CSVPath
        }
    
        # Determine the CSV file name through string addition.
        [String]$CSVFileName = "$CSVPath\WindowsAdminCenter_DeviceDiscovery_$(Get-Date -Format FileDateTime).csv"

        # Write the connections to a CSV file
        Write-Information $("{0}`tGenerating a CSV file and saving to {1}" -f $(Get-Date -Format "G"),$CSVFileName) -InformationVariable +INFO
        $($Computers+$Servers)| Sort-Object -Property Name | Where-Object {$null -ne $_.Name} | Export-Csv -Path $CSVFileName -Force -NoTypeInformation

    <# Import connections into WAC from the generated CSV file #>
        Write-Information $("{0}`tImporting CSV file {1} to WAC ({2})" -f $(Get-Date -Format "G"),$CSVPath,$GATEWAY) -InformationVariable +INFO
        Import-Connection -Prune -GatewayEndpoint $GATEWAY -FileName $CSVFileName -ErrorAction SilentlyContinue -ErrorVariable +INFO -InformationVariable +INFO

    <# Write Log to File #>
        # Determine where to write the log file. Check if a path was passed at runtime or if the path in the configuration file should be used.
        if ($LogPath -eq ""){
            $LogPath = $CONFIG.Connections.Logs.LogPath
        }

        # Determine the log file name through string addition.
        [String]$LogFileName = "$LogPath\WindowsAdminCenter_DeviceDiscovery_$(Get-Date -Format FileDateTime).txt"

        Write-Information $("{0}`tWriting Log file to {1}" -f $(Get-Date -Format "G"),$LogFileName) -InformationVariable +INFO
        Write-Information $("{0} ******** Finished Logging *******" -f $(Get-Date -Format "G")) -InformationVariable +INFO
        
        # Write the log file
        $INFO | Out-File -FilePath $LogFileName -Force

    <# Cleanup old Logs by deleting logs older than the past N days #>
        Start-Process -FilePath cmd.exe -ArgumentList "/c forfiles /P $LogPath /M *.txt /D $([Int]$CONFIG.Connections.Logs.DaysToRetainLogs) /C `"cmd.exe /c del @file /q`""

    <# Cleanup old CSVs by deleting files older than the past N days #>
        Start-Process -FilePath cmd.exe -ArgumentList "/c forfiles /P $LogPath /M *.csv /D $([Int]$CONFIG.Connections.CSV.DaysToRetainCSV) /C `"cmd.exe /c del @file /q`""
}
Import-WACConnections -ConfigFile "$PSScriptRoot\Config.json"