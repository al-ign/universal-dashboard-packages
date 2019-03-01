$PageTitle = 'vSphere PowerCLI Configuration'


#Create UDPage Endpoint
$scriptBlock = {
    #Your content here
    New-UDCard -Text ('Dashboard is running under ' + $env:USERDOMAIN + '\' + $env:USERNAME)

    $arrProp = 'DefaultVIServerMode Scope WebOperationTimeoutSeconds' -split ' '

    New-UDTable -Title $PageTitle `
        -Headers $arrProp `
        -ArgumentList @($arrProp) `
        -Endpoint {
            #Explicitly load vmware modules in case EndpointInitialization didn't kick in
            $vmwareModulesList = @(
            'VMware.VimAutomation.Common', 
            'VMware.VimAutomation.Core', 
            'VMware.VimAutomation.Vds'
            )

            Import-Module $vmwareModulesList

            $arrProp = $ArgumentList
            Get-PowerCLIConfiguration | Select-Object `
            @{N='DefaultVIServerMode';E={$_.DefaultVIServerMode.ToString()}},
            @{N='Scope';E={$_.Scope.ToString()}},
            @{N='WebOperationTimeoutSeconds';E={$_.WebOperationTimeoutSeconds.ToString()}} |  Out-UDTableData -Property $arrProp
            }
    
        New-UDLayout -Columns 2 -Content {


            New-UDButton -Text 'Set mode to Multiple, AllUsers' -OnClick {
                try {
                    Set-PowerCLIConfiguration -DefaultVIServerMode Multiple -Scope AllUsers -Confirm:$false
                    Show-UDToast -Message ( 'Configuration set to Multiple, AllUsers') -Duration 5000 -BackgroundColor DarkGreen -MessageColor White
                    }
                catch {
                    Show-UDToast -Message ( 'Configuration set failed:  ' + $Error[0].Exception ) -Duration 10000 -BackgroundColor Red -MessageColor White
                    }
                }# End UDButton


            New-UDButton -Text 'Set mode to Single, AllUsers' -OnClick {
                try {
                    Set-PowerCLIConfiguration -DefaultVIServerMode Single -Scope AllUsers -Confirm:$false
                    Show-UDToast -Message ( 'Configuration set to Single, AllUsers') -Duration 5000 -BackgroundColor DarkGreen -MessageColor White
                    }
                catch {
                    Show-UDToast -Message ( 'Configuration set failed:  ' + $Error[0].Exception ) -Duration 10000 -BackgroundColor Red -MessageColor White
                    }
                }# End UDButton


            New-UDButton -Text 'Set mode to Multiple, User' -OnClick {
                try {
                    Set-PowerCLIConfiguration -DefaultVIServerMode Multiple -Scope User -Confirm:$false
                    Show-UDToast -Message ( 'Configuration set to Multiple, User') -Duration 5000 -BackgroundColor DarkGreen -MessageColor White
                    }
                catch {
                    Show-UDToast -Message ( 'Configuration set failed:  ' + $Error[0].Exception ) -Duration 10000 -BackgroundColor Red -MessageColor White
                    }
                }# End UDButton


            New-UDButton -Text 'Set mode to Single, User' -OnClick {
                try {
                    Set-PowerCLIConfiguration -DefaultVIServerMode Single -Scope User -Confirm:$false
                    Show-UDToast -Message ( 'Configuration set to Single, User') -Duration 5000 -BackgroundColor DarkGreen -MessageColor White
                    }
                catch {
                    Show-UDToast -Message ( 'Configuration set failed:  ' + $Error[0].Exception ) -Duration 10000 -BackgroundColor Red -MessageColor White
                    }
                }# End UDButton

        } #End UDLayout

    #footer
    New-UDParagraph -Text "This page was generated at $(Get-Date)"
    } #End UDPage ScriptBlock


#Create proper URL
$PageUrl = '/{0}' -f $PageTitle #-replace '\s','-'

#Create UDPage variable
New-Variable -Name ("UDPage" + $PageTitle -replace '\s') -Value (
    New-UDPage -Url $PageUrl -Endpoint $scriptBlock
    )
