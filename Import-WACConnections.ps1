function Import-WACConnections {
    <#
    .SYNOPSIS
    Script for importing Computers and Servers into Windows Admin Center
    
    .DESCRIPTION
    The script parses through Active Directory and tags each device with the appropriate tag based on the device's OU membership
    
    .PARAMETER Gateway
    URL of the Windows Admin Center gateway
    
    .PARAMETER FilePath
    FilePath to the CSV file that has the properly formatted discovered connections
    
    .EXAMPLE
    Import-WACConnections -Gateway "http://localhost:8080" -FilePath "C:\Temp\Connections.csv"
    
    .NOTES
        Author: Paul Boyer
        Date: 4-23-21
    #>
    param (
        [Parameter(Mandatory=$true, ParameterSetName="CommandLine")]
        [Parameter(Mandatory=$false, ParameterSetName="ConfigFile")]
        [String]
        $Gateway,
        [Parameter(Mandatory=$true, ParameterSetName="CommandLine")]
        [Parameter(Mandatory=$false, ParameterSetName="ConfigFile")]
        [ValidateScript({
            # Check that a path to a CSV file was passed
            if([IO.Path]::getExtension($_) -eq ".csv"){
                $true
            }else{
                $false
            }
        })]
        [String]
        $CSVFilePath,
        [Parameter(Mandatory=$false, ParameterSetName="CommandLine")]
        [String]
        $LogPath,
        [Parameter(Mandatory=$true, ParameterSetName="ConfigFile")]
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
        [Parameter(Mandatory=$false, ParameterSetName="CNMatch")]
        [Switch]
        $ComputersCNMatch,
        [Parameter(Mandatory=$false, ParameterSetName="CNMatch")]
        [Switch]
        $ServersCNMatch

    )
    #Requires -Module ActiveDirectory

    # Import required modules
        # Import-Module "$env:ProgramFiles\Windows Admin Center\PowerShell\Modules\ConnectionTools\ConnectionTools.psm1"
        Import-Module "\\wsb-sm-wac\c$\Program Files\Windows Admin Center\PowerShell\Modules\ConnectionTools\ConnectionTools.psm1"
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

        # Variable to hold log information
        [String]$INFO

    <# Variables #>
        # Computer Configuration #
        [String[]]$Computer_SearchBaseList = $CONFIG.Connections.Computers.SearchBases.SearchBase

        # Server Configuration #
        [String[]]$Server_SearchBaseList = $CONFIG.Connections.Servers.SearchBases.SearchBase

    Write-Information $("`t{0} ******** Begin Logging *******`n" -f $(Get-Date -Format "G")) -InformationVariable +INFO

    <# Discover Computers to import into WAC #>
        Write-Information $("{0}`tBegin importing Computers into Windows Admin Center ({1})`n" -f $(Get-Date -Format "G"),$Gateway.ToUpper()) -InformationVariable +INFO

        # Tags to apply to all imported computers
        [String[]]$Computer_Tags = $CONFIG.Connections.Computers.DefaultTags

        # Array list to hold Computer objects
        [System.Collections.ArrayList]$Computers = @(); 

        # Parse through the SearchBase list for computer objects
        foreach($s in $Computer_SearchBaseList){
            Get-ADComputer -Filter * -SearchBase $s | ForEach-Object{
                # Clear tagging for each iteration through the loop. Then add back in necessary tags
                [String[]]$private:Tags = $null;

                # Apply the default computer tags
                $Tags += $Computer_Tags;
                
                # Apply the tags correlated to the SearchBase
                $Tags += ($CONFIG.Connections.Computers.SearchBases | Where-Object{$_.SearchBase -eq $s}).Tags;
    
                #Add computers to an array list as custom objects
                $Computers.Add(
                    [PSCustomObject]@{
                        name = $_.DNSHostname
                        type = $WIN_PC
                        tags = $($Tags -join '|');
                        groupId = "global"
                    } 
                ) | ForEach-Object {
                    Write-Information $("`n{0}`tDiscovered PC {1}" -f $(Get-Date -Format "G"),$Computers[$_].name) -InformationVariable +INFO
                }
            }
            # Add an empty line for spacing/formatting
            Write-Information "`n" -InformationVariable +INFO
        }
    <# Discover Servers to import into WAC #>
        Write-Information $("`n{0}`tBegin importing Servers into Windows Admin Center ({1})`n" -f $(Get-Date -Format "G"),$Gateway.ToUpper()) -InformationVariable +INFO

        # Tags to apply to all imported servers
        [String[]]$Server_Tags = $CONFIG.Connections.Servers.DefaultTags

        # Array list to hold all Server objects
        [System.Collections.ArrayList]$Servers = @();

        foreach($s in $Server_SearchBaseList){
            Get-ADComputer -Filter * -SearchBase $s | ForEach-Object {
    
                # Clear tagging for each iteration through the loop. Then add back in necessary tags
                [String[]]$private:Tags = $null;

                # Apply the default server tags
                $Tags += $Server_Tags;

                # Apply the tags correlated to the SearchBase
                $Tags += ($CONFIG.Connections.Servers.SearchBases | Where-Object{$_.SearchBase -eq $s}).Tags;
    
                #Add computers to an array list as custom objects
                $Servers.Add(
                    [PSCustomObject]@{
                        name = $_.DNSHostname
                        type = $WIN_SERVER
                        tags = $($Tags -join '|');
                        groupId = "global"
                    } 
                ) | ForEach-Object {
                    Write-Information $("`n{0}`tDiscovered Server {1}" -f $(Get-Date -Format "G"),$Servers[$_].name) -InformationVariable +INFO
                }
            }
        }
    
    <# Generate a CSV file for importing into WAC #>
        # Resolve the $CSVFilePath location
        if ($CSVFilePath -eq $null -or $CSVFilePath -eq ""){
            $CSVFilePath = $CONFIG.Connections.Computers.CSVFilePath
        }
    
        # Write the connections to a CSV file
        Write-Information $("`n`t{0} Generating a CSV file and saving to {1}" -f $(Get-Date -Format "G"),$CSVFilePath) -InformationVariable +INFO
        $($Computers+$Servers)| Sort-Object -Property Name | Where-Object {$null -ne $_.Name} | Export-Csv -Path $CSVFilePath -Force -NoTypeInformation

    <# Import connections into WAC from the generated CSV file #>
        Write-Information $("`n`t{0} Importing CSV file {1} to WAC ({2})" -f $(Get-Date -Format "G"),$CSVFilePath,$Gateway) -InformationVariable +INFO
        # Import-Connection -Prune -GatewayEndpoint $Gateway -FileName $CSVFilePath -ErrorAction SilentlyContinue -ErrorVariable +INFO -InformationVariable +INFO

    <# Write Log to File #>
        # Determine where to write the log file
        if ($LogPath -eq $null -or $LogPath -eq ""){
            $LogPath = $CONFIG.Connections.Logs.LogPath
        }
        Write-Information $("`n`t{0} Writing Log file to {1}" -f $(Get-Date -Format "G"),$($(Split-Path $LogPath -Parent)+"\"+$(Get-Date -Format FileDateTime)+".txt")) -InformationVariable +INFO
        Write-Information $("`n`t{0} ******** Finished Logging *******`n" -f $(Get-Date -Format "G")) -InformationVariable +INFO
        $INFO | Out-File -FilePath  $($LogPath+"\"+$(Get-Date -Format FileDateTime)+".txt") -Force

    <# Cleanup old Logs by deleting logs older than the past 7 days #>
        Start-Process -FilePath cmd.exe -ArgumentList "/c forfiles /P $LogPath /M *.txt /D $([Int]$CONFIG.Connections.Logs.DaysToRetainLogs) /C `"cmd.exe /c del @file /q`""
}
Import-WACConnections -Gateway "https://localhost:6516" -CSVFilePath $PSScriptRoot\WACConnections.csv -ConfigFile $PSScriptRoot\Test.json