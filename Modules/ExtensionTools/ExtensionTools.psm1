#########################################################################################
#
# Copyright (c) Microsoft Corporation. All rights reserved.
#
# Extension Tools
#
#Requires -Version 4.0
#
#########################################################################################

add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@

Function Get-Params {
    param(
        [Parameter(Mandatory = $false)]
        [Uri]
        $GatewayEndpoint,
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential
    )
    if ( $GatewayEndpoint -eq $null ) {
        try
        {
            $GatewayEndpoint = [Uri] ( Get-ItemPropertyValue 'HKCU:\Software\Microsoft\ServerManagementGateway' 'SmeDesktopEndpoint' )
        }
        catch
        {
            throw (New-Object System.Exception -ArgumentList 'No endpoint was specified so a local gateway was assumed and it must be run at least once.')
        }
    }
    $params = @{useBasicParsing = $true; userAgent = "PowerShell"}
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    $clientCertificateThumbprint = ''
    $IsLocal = $GatewayEndpoint.IsLoopback -or ( $GatewayEndpoint.Host -eq $Env:ComputerName )
    if ( ( $GatewayEndpoint.Scheme -eq [Uri]::UriSchemeHttps ) -and $IsLocal ) {  
        $clientCertificateThumbprint = (Get-ChildItem 'Cert:\CurrentUser\My' | Where-Object { $_.Subject -eq 'CN=Windows Admin Center Client' }).Thumbprint
    }
    if ($clientCertificateThumbprint) {
        $params.certificateThumbprint = "$clientCertificateThumbprint"
    }
    else {
        if ($Credential) {
            $params.credential = $Credential
        }
        else {
            $params.useDefaultCredentials = $True
        }
    }
    $params.uri = "$($GatewayEndpoint)/api/extensions";
    return $params
}

Function Get-RecentVersion($extensions) {
    $recent = $extensions[0]
    $extensions | ForEach-Object { 
        if ($Null -eq $recent -Or [System.Version]$recent.version -le [System.Version]$_.version) { 
            $recent = $_ 
        } 
    }
    return $recent
}

<#
.SYNOPSIS
Show the feeds available in the Windows Admin Center Gateway.

.DESCRIPTION
The function list the available feeds.

.PARAMETER GatewayEndpoint
Required. Provide the gateway name.

.PARAMETER Credential
Optional. If you wish to provide credentials to the Windows Admin Center gateway which are different from your credentials on the computer where you're executing the script, provide a PSCredential by using Get-Credential. You can also provide just the username for this parameter and you will be prompted to enter the corresponding password (which gets stored as a SecureString).

.EXAMPLE
C:\PS> Get-Feed -GatewayEndpoint "https://localhost:4100"
#>
Function Get-Feed {
    param(
        [Parameter(Mandatory = $false)]
        [Uri]
        $GatewayEndpoint,
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential
    )
    $params = Get-Params $GatewayEndpoint $Credential
    $params.uri = $params.uri + "/configs";
    $params.method = "Get"
    $response = Invoke-WebRequest @params
    if ($response.StatusCode -ne 200 ) {
        throw "Failed to get the feeds"
    }
    $packageFeeds = ConvertFrom-Json $response.Content
    $packageFeeds = $packageFeeds.packageFeeds
    return $packageFeeds
}

<#
.SYNOPSIS
Add a feed to the Windows Admin Center Gateway.

.DESCRIPTION
The function add a feed.

.PARAMETER GatewayEndpoint
Required. Provide the gateway name.

.PARAMETER Feed
Required. Provide the Feed url.

.PARAMETER Credential
Optional. If you wish to provide credentials to the Windows Admin Center gateway which are different from your credentials on the computer where you're executing the script, provide a PSCredential by using Get-Credential. You can also provide just the username for this parameter and you will be prompted to enter the corresponding password (which gets stored as a SecureString).

.EXAMPLE
C:\PS> Add-Feed -GatewayEndpoint "https://localhost:4100" -Feed "https://aka.ms/sme-extension-feed"
#>
Function Add-Feed {
    param(
        [Parameter(Mandatory = $false)]
        [Uri]
        $GatewayEndpoint,
        [Parameter(Mandatory = $true)]
        [String]
        $Feed,
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential
    )   
    $packageFeeds = [PSCustomObject]@{packageFeeds = @(Get-Feed $GatewayEndpoint $Credential)}
    if ($packageFeeds.packageFeeds -Contains $Feed) {
        Write-Warning "The feed '$Feed' already exist in the gateway"
        return
    }
    $params = Get-Params $GatewayEndpoint $Credential
    $params.uri = $params.uri + "/configs";
    $params.method = "Put"
    $packageFeeds.packageFeeds += $Feed
    $params.body = ConvertTo-Json $packageFeeds   
    $response = Invoke-WebRequest @params
    if ($response.StatusCode -ne 200 ) {
        throw "Failed to add the feed in the gateway"
    }
    return [PSCustomObject]@(Get-Feed $GatewayEndpoint $Credential)
}

<#
.SYNOPSIS
Remove a feed to the Windows Admin Center Gateway.

.DESCRIPTION
The function remove a feed.

.PARAMETER GatewayEndpoint
Required. Provide the gateway name.

.PARAMETER Feed
Required. Provide the Feed url.

.PARAMETER Credential
Optional. If you wish to provide credentials to the Windows Admin Center gateway which are different from your credentials on the computer where you're executing the script, provide a PSCredential by using Get-Credential. You can also provide just the username for this parameter and you will be prompted to enter the corresponding password (which gets stored as a SecureString).

.EXAMPLE
C:\PS> Remove-Feed -GatewayEndpoint "https://localhost:4100" -Feed "https://aka.ms/sme-extension-feed"
#>
Function Remove-Feed {
    param(
        [Parameter(Mandatory = $false)]
        [Uri]
        $GatewayEndpoint,
        [Parameter(Mandatory = $true)]
        [String]
        $Feed,
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential
    )   
    $packageFeeds = [PSCustomObject]@{packageFeeds = @(Get-Feed $GatewayEndpoint $Credential)}
    if ($packageFeeds.packageFeeds -NotContains $Feed) {
        Write-Warning "The feed '$Feed' not exist in the gateway"
    }
    else {
        $removeFeed = [PSCustomObject]@($packageFeeds.packageFeeds | Where-Object { $_ -eq $Feed })
        $params = Get-Params $GatewayEndpoint $Credential
        $params.uri = $params.uri + "/configs";
        $params.method = "Put"
        $packageFeeds.packageFeeds = @($packageFeeds.packageFeeds | Where-Object { $_ -Ne $Feed })
        $params.body = ConvertTo-Json $packageFeeds   
        $response = Invoke-WebRequest @params
        if ($response.StatusCode -ne 200 ) {
            throw "Failed to remove the feed in the gateway"
        }
    }
    return $removeFeed
}

<#
.SYNOPSIS
Show the extension available in the Windows Admin Center Gateway.

.DESCRIPTION
The function list the available extensions.

.PARAMETER GatewayEndpoint
Required. Provide the gateway name.

.PARAMETER Credential
Optional. If you wish to provide credentials to the Windows Admin Center gateway which are different from your credentials on the computer where you're executing the script, provide a PSCredential by using Get-Credential. You can also provide just the username for this parameter and you will be prompted to enter the corresponding password (which gets stored as a SecureString).

.EXAMPLE
C:\PS> Get-Extension -GatewayEndpoint "https://localhost:4100"
#>
Function Get-Extension {
    param(
        [Parameter(Mandatory = $false)]
        [Uri]
        $GatewayEndpoint,
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential
    )
    $params = Get-Params $GatewayEndpoint $Credential
    $params.method = "Get"
    $response = Invoke-WebRequest @params
    if ($response.StatusCode -ne 200 ) {
        throw "Failed to get the extensions"
    }
    $content = ConvertFrom-Json $response.Content
    $extensions = $content.Extensions
    return $extensions
}

<#
.SYNOPSIS
Install a Windows Admin Center Extension.

.DESCRIPTION
The function install a specific extension.

.PARAMETER GatewayEndpoint
Required. Provide the gateway name.

.PARAMETER ExtensionId
Required. Specifies the Id for the extension.

.PARAMETER Version
Optional. Specifies a version, if is not present, The function search for the latest one.

.PARAMETER Feed
Optional. Specifies a feed, if is not present, The function add it.

.PARAMETER Credential
Optional. If you wish to provide credentials to the Windows Admin Center gateway which are different from your credentials on the computer where you're executing the script, provide a PSCredential by using Get-Credential. You can also provide just the username for this parameter and you will be prompted to enter the corresponding password (which gets stored as a SecureString).

.EXAMPLE
C:\PS> Install-Extension -GatewayEndpoint "https://localhost:4100" -ExtensionId "DataON.MUST"
#>
Function Install-Extension {
    param(
        [Parameter(Mandatory = $false)]
        [Uri]
        $GatewayEndpoint,
        [Parameter(Mandatory = $true)]
        [String]
        $ExtensionId,
        [Parameter(Mandatory = $false)]
        [String]
        $Version,        
        [Parameter(Mandatory = $false)]
        [String]
        $Feed,
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential
    )

    $NotFoundLegend = "The extension '$ExtensionId' is not available in the "
    if ($PSBoundParameters.ContainsKey("Feed")) {
        if (!$Feed) {
            $NotFoundLegend += "Pre-installed catalog"
            $extensions = @(Get-Extension $GatewayEndpoint $Credential | Where-Object { $_.id -eq $ExtensionId -And $_.packageSource -eq $Null})
        }
        else {
            # Check if exist the Feed otherwise install it 
            $Feeds  = Get-Feed $GatewayEndpoint $Credential
            if ($Feeds -NotContains $Feed){
                Write-Warning "The feed '$Feed' not exist in the gateway, trying to add it"
                Add-Feed $GatewayEndpoint $Feed $Credential
            }
            $NotFoundLegend += "$Feed feed"
            $extensions = @(Get-Extension $GatewayEndpoint $Credential | Where-Object { $_.id -eq $ExtensionId -And $_.packageSource -eq $Feed})
        }
    } else {
        $NotFoundLegend += "current feeds"
        $extensions = @(Get-Extension $GatewayEndpoint $Credential | Where-Object { $_.id -eq $ExtensionId })
    }

    if (!$extensions) {
        Write-Warning $NotFoundLegend
        return
    }

    if ($Version) {
        $extensions = @($extensions | Where-Object { $_.version -eq $Version })
    }    
    if (!$extensions) {
        Write-Warning "The extension: '$ExtensionId' ('$Version') is not present" 
        return
    }

    $extension = Get-RecentVersion $extensions
    $params = Get-Params $GatewayEndpoint $Credential
    $params.uri = $params.uri + "/" + $extension.id + "/versions/" + $extension.version + "/install";
    $params.method = "Post"
    Try {
        $response = Invoke-WebRequest @params
    } 
    Catch {
        $error = ConvertFrom-Json $_
        throw $error.error.message
    }
    if ($response.StatusCode -ne 200 ) {
        throw "Failed to install the extension in the gateway"
    }
    return $extension
}

<#
.SYNOPSIS
Uninstall a Windows Admin Center Extension.

.DESCRIPTION
The function uninstall the selected extension.

.PARAMETER GatewayEndpoint
Required. Provide the gateway name.

.PARAMETER ExtensionId
Required. Specifies the Id for the extension.

.PARAMETER Credential
Optional. If you wish to provide credentials to the Windows Admin Center gateway which are different from your credentials on the computer where you're executing the script, provide a PSCredential by using Get-Credential. You can also provide just the username for this parameter and you will be prompted to enter the corresponding password (which gets stored as a SecureString).

.EXAMPLE
C:\PS> Uninstall-Extension -GatewayEndpoint "https://localhost:4100" -ExtensionId "DataON.MUST"
#>
Function Uninstall-Extension {
    param(
        [Parameter(Mandatory = $false)]
        [Uri]
        $GatewayEndpoint,
        [Parameter(Mandatory = $true)]
        [String]
        $ExtensionId,
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential
    )

    $extension = Get-Extension $GatewayEndpoint $Credential | Where-Object { $_.id -eq $ExtensionId -And $_.status -eq "Installed" }
    if (!$extension) {
        Write-Warning "The extension: '$ExtensionId' is not installed"
        return 
    }

    $params = Get-Params $GatewayEndpoint $Credential
    $params.uri = $params.uri + "/" + $extension.id + "/versions/" + $extension.version + "/uninstall";
    $params.method = "Post"
    Try {
        $response = Invoke-WebRequest @params
    } 
    Catch {
        $error = ConvertFrom-Json $_
        throw $error.error.message
    }
    if ($response.StatusCode -ne 200 ) {
        throw "Failed to uninstall the extension in the gateway"
    }
    return $extension
}

<#
.SYNOPSIS
Update a Windows Admin Center Extension.

.DESCRIPTION
The function update the selected extension with the most recent version available.

.PARAMETER GatewayEndpoint
Required. Provide the gateway name.

.PARAMETER ExtensionId
Required. Specifies the Id for the extension.

.PARAMETER Feed
Optional. Specifies a feed, if is not present, The function add it.

.PARAMETER Credential
Optional. If you wish to provide credentials to the Windows Admin Center gateway which are different from your credentials on the computer where you're executing the script, provide a PSCredential by using Get-Credential. You can also provide just the username for this parameter and you will be prompted to enter the corresponding password (which gets stored as a SecureString).

.EXAMPLE
C:\PS> Update-Extension -GatewayEndpoint "https://localhost:4100" -ExtensionId "DataON.MUST"
#>
Function Update-Extension {
    param(
        [Parameter(Mandatory = $false)]
        [Uri]
        $GatewayEndpoint,
        [Parameter(Mandatory = $true)]
        [String]
        $ExtensionId,      
        [Parameter(Mandatory = $false)]
        [String]
        $Feed,
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential
    )

    if ($PSBoundParameters.ContainsKey("Feed")) {
        if ($Feed) {
            $Feeds  = Get-Feed $GatewayEndpoint $Credential
            if ($Feeds -NotContains $Feed){
                Write-Warning "The feed '$Feed' not exist in the gateway, trying to add it"
                Add-Feed $GatewayEndpoint $Feed $Credential
            }
        }
    }

    $extension = Get-Extension $GatewayEndpoint $Credential | Where-Object { $_.id -eq $ExtensionId -And $_.status -eq "Installed"}
    if (!$extension) {
        Write-Warning "The extension: '$ExtensionId' is not installed"
        return 
    }
    $params = Get-Params $GatewayEndpoint $Credential
    $params.uri = $params.uri + "/" + $extension.id + "/versions/" + $extension.version + "/update";
    $params.method = "Post"
    Try {
        $response = Invoke-WebRequest @params
    } 
    Catch {
        $error = ConvertFrom-Json $_
        throw $error.error.message
    }
    if ($response.StatusCode -ne 200 ) {
        throw "Failed to update the extension in the gateway"
    }
    return $extension
}

Export-ModuleMember -Function Get-Feed
Export-ModuleMember -Function Add-Feed
Export-ModuleMember -Function Remove-Feed
Export-ModuleMember -Function Get-Extension
Export-ModuleMember -Function Install-Extension
Export-ModuleMember -Function Uninstall-Extension
Export-ModuleMember -Function Update-Extension
# SIG # Begin signature block
# MIIjnwYJKoZIhvcNAQcCoIIjkDCCI4wCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCL/H2ElBzA947L
# 0FeEOoqHZQvYGCKxgct+SO+ctNB2wqCCDYEwggX/MIID56ADAgECAhMzAAAB32vw
# LpKnSrTQAAAAAAHfMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjAxMjE1MjEzMTQ1WhcNMjExMjAyMjEzMTQ1WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQC2uxlZEACjqfHkuFyoCwfL25ofI9DZWKt4wEj3JBQ48GPt1UsDv834CcoUUPMn
# s/6CtPoaQ4Thy/kbOOg/zJAnrJeiMQqRe2Lsdb/NSI2gXXX9lad1/yPUDOXo4GNw
# PjXq1JZi+HZV91bUr6ZjzePj1g+bepsqd/HC1XScj0fT3aAxLRykJSzExEBmU9eS
# yuOwUuq+CriudQtWGMdJU650v/KmzfM46Y6lo/MCnnpvz3zEL7PMdUdwqj/nYhGG
# 3UVILxX7tAdMbz7LN+6WOIpT1A41rwaoOVnv+8Ua94HwhjZmu1S73yeV7RZZNxoh
# EegJi9YYssXa7UZUUkCCA+KnAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUOPbML8IdkNGtCfMmVPtvI6VZ8+Mw
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDYzMDA5MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAnnqH
# tDyYUFaVAkvAK0eqq6nhoL95SZQu3RnpZ7tdQ89QR3++7A+4hrr7V4xxmkB5BObS
# 0YK+MALE02atjwWgPdpYQ68WdLGroJZHkbZdgERG+7tETFl3aKF4KpoSaGOskZXp
# TPnCaMo2PXoAMVMGpsQEQswimZq3IQ3nRQfBlJ0PoMMcN/+Pks8ZTL1BoPYsJpok
# t6cql59q6CypZYIwgyJ892HpttybHKg1ZtQLUlSXccRMlugPgEcNZJagPEgPYni4
# b11snjRAgf0dyQ0zI9aLXqTxWUU5pCIFiPT0b2wsxzRqCtyGqpkGM8P9GazO8eao
# mVItCYBcJSByBx/pS0cSYwBBHAZxJODUqxSXoSGDvmTfqUJXntnWkL4okok1FiCD
# Z4jpyXOQunb6egIXvkgQ7jb2uO26Ow0m8RwleDvhOMrnHsupiOPbozKroSa6paFt
# VSh89abUSooR8QdZciemmoFhcWkEwFg4spzvYNP4nIs193261WyTaRMZoceGun7G
# CT2Rl653uUj+F+g94c63AhzSq4khdL4HlFIP2ePv29smfUnHtGq6yYFDLnT0q/Y+
# Di3jwloF8EWkkHRtSuXlFUbTmwr/lDDgbpZiKhLS7CBTDj32I0L5i532+uHczw82
# oZDmYmYmIUSMbZOgS65h797rj5JJ6OkeEUJoAVwwggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIVdDCCFXACAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAd9r8C6Sp0q00AAAAAAB3zAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgm9U1Y3Wr
# mwkavbQt4oS2PcLacbqNgLIcQKDlnGky/MEwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQA7y+vXLmu8MKCROR7fr5M8nUtzmSVETmB7WHQ2QPRu
# p9pjbywNve4q8/z48jpEYe/zmkC8iytPu8wJBnRgYYgq8AEk7cmo8XpibbYrW18Z
# j5aqq37d20BFAv1DpcqbEd7wkMR6k1BYsKhT4vV9tyPcRw8m6iels1Y3kMxIFI4X
# +4yOHPFj8XW0iiV+8+sYMfMg0m7Hi1RS74zoEeKVR00c3KC5nPl53TrJnztU51Ug
# Z/N4HcNFoTGMsQ33591AG8GkYuph9fLLqXecdDTL8bxAhlDKiETqnfOTTxFX/DR8
# NUax90bvnaCcb0t8g9dc+SlPoTYwGaIzCBiQF2GEfcfvoYIS/jCCEvoGCisGAQQB
# gjcDAwExghLqMIIS5gYJKoZIhvcNAQcCoIIS1zCCEtMCAQMxDzANBglghkgBZQME
# AgEFADCCAVkGCyqGSIb3DQEJEAEEoIIBSASCAUQwggFAAgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIDYY7YqIWSjM1Jme7pX8TLclcZQTb7pdgfcQoG6e
# OsQeAgZgPN+gAL4YEzIwMjEwMzAyMDcxNjQ0Ljg5NFowBIACAfSggdikgdUwgdIx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEmMCQGA1UECxMdVGhh
# bGVzIFRTUyBFU046RTA0MS00QkVFLUZBN0UxJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2Wggg5NMIIE+TCCA+GgAwIBAgITMwAAATdBj0PnWltv
# pwAAAAABNzANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0Eg
# MjAxMDAeFw0yMDEwMTUxNzI4MTRaFw0yMjAxMTIxNzI4MTRaMIHSMQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQg
# SXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1Mg
# RVNOOkUwNDEtNEJFRS1GQTdFMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBTZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxBHuadEl
# m3G5tikhTzjSDB0+9sXmUhUyDVRj0Y4vz9rZ9sykNobL5/6At5zOkeB2bl9IXvVd
# yS/ZJNZT373knzrQ347z30Mmw7++VU/CE+4x4w9kb5bqQHfSzbJQt6KmWsuMmJLz
# g4R5MeJs5MY5YdPLxoMoDRcTi//KoMFR0KzS1/324D2/4KkHD1Xt+s0xY0DICUOK
# 1RbmJCKEgBP1/GDZjuZQBS9Di89yTnvLJV+Lr1QtriH4EqmRoAdmV3zJ0GJsr5vh
# GPmKfOPCRSk7Q8igX7goFnCLzpYcfHGCqoR/mw95gfQpwymVwxZB0PkGMrQw+LKV
# Pa/FHP4C4KO+QQIDAQABo4IBGzCCARcwHQYDVR0OBBYEFA1gsHMM+udgY7rEne66
# OyzxlE9lMB8GA1UdIwQYMBaAFNVjOlyKMZDzQ3t8RhvFM2hahW1VMFYGA1UdHwRP
# ME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1
# Y3RzL01pY1RpbVN0YVBDQV8yMDEwLTA3LTAxLmNybDBaBggrBgEFBQcBAQROMEww
# SgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMv
# TWljVGltU3RhUENBXzIwMTAtMDctMDEuY3J0MAwGA1UdEwEB/wQCMAAwEwYDVR0l
# BAwwCgYIKwYBBQUHAwgwDQYJKoZIhvcNAQELBQADggEBAJ32U9d90RVuAUb9NsnX
# BG1K42qjhU+jHvwBdbipIcX4Wg7dH5ZduQZj3gWgKADZ5z+TehX7GnBbi265VI7x
# DRsFe2CjkTm4JIoisdKwYBDruS+YRRBG4B1ERuWi54XGwx+lSA+iQNrIi6Jm0CL/
# MfQLvwsqPJSGP69OEHCyaExos486+X3JTuGV11CBl/BO7r8UHbx/rE6fZrlZZYab
# IF6aeahvTL14LvZLV/bMzYSODsbjHHsTm9QaGm1ijhagCdbkAqr8+7HAgYEar8XP
# lzxUhVI4ShVB5ZGd9gZ2yBkwxdA0oFc745TdOPrbP79vd0ePqgvJDH5tkOhTRNI5
# 5XQwggZxMIIEWaADAgECAgphCYEqAAAAAAACMA0GCSqGSIb3DQEBCwUAMIGIMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNy
# b3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAeFw0xMDA3MDEy
# MTM2NTVaFw0yNTA3MDEyMTQ2NTVaMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpX
# YXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAy
# MDEwMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqR0NvHcRijog7PwT
# l/X6f2mUa3RUENWlCgCChfvtfGhLLF/Fw+Vhwna3PmYrW/AVUycEMR9BGxqVHc4J
# E458YTBZsTBED/FgiIRUQwzXTbg4CLNC3ZOs1nMwVyaCo0UN0Or1R4HNvyRgMlhg
# RvJYR4YyhB50YWeRX4FUsc+TTJLBxKZd0WETbijGGvmGgLvfYfxGwScdJGcSchoh
# iq9LZIlQYrFd/XcfPfBXday9ikJNQFHRD5wGPmd/9WbAA5ZEfu/QS/1u5ZrKsajy
# eioKMfDaTgaRtogINeh4HLDpmc085y9Euqf03GS9pAHBIAmTeM38vMDJRF1eFpwB
# BU8iTQIDAQABo4IB5jCCAeIwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFNVj
# OlyKMZDzQ3t8RhvFM2hahW1VMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsG
# A1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFNX2VsuP6KJc
# YmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9z
# b2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIz
# LmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3J0
# MIGgBgNVHSABAf8EgZUwgZIwgY8GCSsGAQQBgjcuAzCBgTA9BggrBgEFBQcCARYx
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL1BLSS9kb2NzL0NQUy9kZWZhdWx0Lmh0
# bTBABggrBgEFBQcCAjA0HjIgHQBMAGUAZwBhAGwAXwBQAG8AbABpAGMAeQBfAFMA
# dABhAHQAZQBtAGUAbgB0AC4gHTANBgkqhkiG9w0BAQsFAAOCAgEAB+aIUQ3ixuCY
# P4FxAz2do6Ehb7Prpsz1Mb7PBeKp/vpXbRkws8LFZslq3/Xn8Hi9x6ieJeP5vO1r
# VFcIK1GCRBL7uVOMzPRgEop2zEBAQZvcXBf/XPleFzWYJFZLdO9CEMivv3/Gf/I3
# fVo/HPKZeUqRUgCvOA8X9S95gWXZqbVr5MfO9sp6AG9LMEQkIjzP7QOllo9ZKby2
# /QThcJ8ySif9Va8v/rbljjO7Yl+a21dA6fHOmWaQjP9qYn/dxUoLkSbiOewZSnFj
# nXshbcOco6I8+n99lmqQeKZt0uGc+R38ONiU9MalCpaGpL2eGq4EQoO4tYCbIjgg
# tSXlZOz39L9+Y1klD3ouOVd2onGqBooPiRa6YacRy5rYDkeagMXQzafQ732D8OE7
# cQnfXXSYIghh2rBQHm+98eEA3+cxB6STOvdlR3jo+KhIq/fecn5ha293qYHLpwms
# ObvsxsvYgrRyzR30uIUBHoD7G4kqVDmyW9rIDVWZeodzOwjmmC3qjeAzLhIp9cAv
# VCch98isTtoouLGp25ayp0Kiyc8ZQU3ghvkqmqMRZjDTu3QyS99je/WZii8bxyGv
# WbWu3EQ8l1Bx16HSxVXjad5XwdHeMMD9zOZN+w2/XU/pnR4ZOC+8z1gFLu8NoFA1
# 2u8JJxzVs341Hgi62jbb01+P3nSISRKhggLXMIICQAIBATCCAQChgdikgdUwgdIx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEmMCQGA1UECxMdVGhh
# bGVzIFRTUyBFU046RTA0MS00QkVFLUZBN0UxJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVAOq7qDk4iVz8ITuZbUFr
# AG7ecxqcoIGDMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJ
# KoZIhvcNAQEFBQACBQDj6AbWMCIYDzIwMjEwMzAyMDgzNTM0WhgPMjAyMTAzMDMw
# ODM1MzRaMHcwPQYKKwYBBAGEWQoEATEvMC0wCgIFAOPoBtYCAQAwCgIBAAICGqUC
# Af8wBwIBAAICEgkwCgIFAOPpWFYCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYB
# BAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQUFAAOB
# gQAQFlBrZEr9mFvlPHPnV0tS4THhQJJKLoZW0JWJKVjdwLhthd9whBO8AsOZag7W
# pZhd1rZm62xhn3GpDd+s9uKmqQwOWEv0g96YxrcgjgsOIFK8SutHn/QVEgsW3IeH
# cZKfF0aiOD7e705089JB3IGc+NLXASJei7y4qAhZFBz8OzGCAw0wggMJAgEBMIGT
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAABN0GPQ+daW2+nAAAA
# AAE3MA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQ
# AQQwLwYJKoZIhvcNAQkEMSIEIISrBKM0RM/C0TZ5DxV/iQrkdGNooPrTsDiZF0bT
# A7UqMIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgHVl+r8CeBJ0iyX/aGZD2
# YbQ7gk+U7N7BQiTDKAYSHBAwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0EgMjAxMAITMwAAATdBj0PnWltvpwAAAAABNzAiBCAFMO+8NsZM6eFI3prLXj+L
# R3s/h2wTN5qpJtgqHqmeTTANBgkqhkiG9w0BAQsFAASCAQAWjiI+Y6OXkvPsh5b4
# j2ra0dhIj3lawrhsIA+sXAYTtNb8SLG3ToHvWDfj2PD5kuZN3Jiw6CH9hJaO8U8w
# eXtCYO1uh62PTh1MD77hd6qW/UAWYD6zQuO42icz9ZF6SRBqeZr2ZmQq3V6v5bPR
# nlNG6kdpIr3ImCMwRb5q2ImHuYghmtsJZdSZ0Btci2cW7QFvIfZQ6rLxp4cMBruM
# cRLqOtVQd8odQFsUyM88BIwVSOB4AxMpIRxQ8wieKuoQZcYYXDsojtrT0tJ2IxSh
# Xl0dpRuf/DSQ1K9qU+loCmnDCkq4412Dh9m4Lp729pxM8aqmyhn7S6x/g2OvttvG
# /5uf
# SIG # End signature block
