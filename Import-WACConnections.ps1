function Import-WACConnections {
    param (
        [Parameter(Mandatory=$true)]
        [String]
        $Gateway,
        [Parameter(Mandatory=$true)]
        [ValidateScript({
            # Check that a path to a CSV file was passed
            if([IO.Path]::getExtension($_) -eq "csv"){
                $true
            }else{
                $false
            }
        })]
        [String]
        $FilePath
    )
    #Requires -Module ActiveDirectory

    # Import required modules
        Import-Module Modules\ConnectionTools\ConnectionTools.psm1

    <# CONSTANTS #>
        # Constant string type for windows 10 PCs
        [String]$WIN10_PC = "msft.sme.connection-type.windows-client"

        # Constant string type for windows servers
        [String]$WIN_SERVER = "msft.sme.connection-type.server"

        # Variable to hold log information
        [String]$INFO

    <# Variables #>
        # Computer Configuration #
        [String[]]$Computer_SearchBaseList = @(
            "OU=Test,DC=ads,DC=ssc,DC=wisc,DC=edu",
            "OU=Windows 10,OU=SSCC,DC=ads,DC=ssc,DC=wisc,DC=edu",
            "OU=High Security,OU=SSCC,DC=ads,DC=ssc,DC=wisc,DC=edu",
            "OU=Windows,OU=Anthropology,DC=ads,DC=ssc,DC=wisc,DC=edu",
            "OU=Lab,DC=ads,DC=ssc,DC=wisc,DC=edu"
        )

        # Server Configuration #
        [String[]]$Server_SearchBaseList = @(
            "OU=Servers,OU=Service,DC=ads,DC=ssc,DC=wisc,DC=edu"
        )

    <# Private Function to parse computer/server objects and tag appropriately #>
    function private:Parse-Tags{
        param(
            [Parameter(Mandatory = $true)]
            [String[]]
            $Tags
        )
        
        return $($Tags -join '|')
    }
}