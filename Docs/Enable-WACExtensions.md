---
Author: Paul Boyer
external help file: WinAdminCenter-help.xml
Module Guid: 59e65a61-edfe-4a14-b887-ca777d6b2e17
Module Name: WinAdminCenter
online version:
schema: 2.0.0
---

# Enable-WACExtensions

## SYNOPSIS
A PowerShell Script to automate the installation and updating of extensions in Windows Admin Center.

## SYNTAX

```
Enable-WACExtensions -ConfigFile <String> [-GatewayURL <String>] [-LogPath <String>] [<CommonParameters>]
```

## DESCRIPTION
The script automates the process of setting up a new Windows Admin Center Gateway instance.
It will automatically install and update the specified extensions in the JSON configuration file.

## EXAMPLES

### EXAMPLE 1
```
Enable-WACExtensions -GatewayURL "https://localhost" -ConfigFile "C:\Temp\WACExtensions.json"
```

## PARAMETERS

### -ConfigFile
The path to the JSON configuration file.
The script will use values defined in this file unless overridden by the function call parameters.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -GatewayURL
An override parameter for the URL of the Windows Admin Center Gateway.
The script will use this value defined in the function call rather than the setting in the JSON configuration file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogPath
An override parameter for the path to the log file.
The script will use this value defined in the function call rather than the setting in the JSON configuration file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
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
Date: 12-21-21

## RELATED LINKS

[https://docs.microsoft.com/en-us/windows-server/manage/windows-admin-center/configure/use-powershell](https://docs.microsoft.com/en-us/windows-server/manage/windows-admin-center/configure/use-powershell)

