---
Author: Paul Boyer
external help file: WinAdminCenter-help.xml
Module Guid: e2aed9d2-2a17-4273-b9ab-909fc8bd5531
Module Name: WinAdminCenter
online version:
schema: 2.0.0
---

# Set-WACDelegatedCredentials

## SYNOPSIS
Script to enable SSO from Windows Admin Center to endpoints

## SYNTAX

```
Set-WACDelegatedCredentials [-ConfigFile] <String> [[-GatewayURI] <String>] [[-LogPath] <String>]
 [<CommonParameters>]
```

## DESCRIPTION
The script enables SSO by setting delegation in AD and clearing the Kerberos cache.
Then sets registry keys to indicate that SSO has been enabled.

## EXAMPLES

### EXAMPLE 1
```
Set-WACDelegatedCredentials -ConfigFile "C:\Temp\Config.json"
```

### EXAMPLE 2
```
Set-WACDelegatedCredentials -ConfigFile "C:\Temp\Config.json" -GatewayURI "https://gateway.contoso.com"
```

## PARAMETERS

### -ConfigFile
A mandatory parameter that specifies the path to the JSON configuration file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -GatewayURI
An override parameter that specifies the URI of Gateway endpoint.
The value from the JSON configuration file will be ignored if this parameter is specified.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogPath
An override parameter that specifies the path to the log file.
The value from the JSON configuration file will be ignored if this parameter is specified.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Author: Paul Boyer
Date: 7-20-2020

## RELATED LINKS

[https://charbelnemnom.com/2019/07/how-to-enable-single-sign-on-sso-for-windows-admin-center/](https://charbelnemnom.com/2019/07/how-to-enable-single-sign-on-sso-for-windows-admin-center/)

