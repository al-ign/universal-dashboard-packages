$PageTitle = 'vSphere Status ViServer'


#Create UDPage Content
$scriptBlock = {
    #Your content here

    $arrProp = @('Name','User', 'IsConnected')
    
    New-UDTable -Title 'Connected ViServers' `
            -Headers $arrProp `
            -ArgumentList @($arrProp) `
            -Endpoint {
                $arrProp = $ArgumentList

                Get-VIServer $UDEPVarViServerList | select name, User, @{N='IsConnected';E={$_.IsConnected.ToString()}} |  Out-UDTableData -Property $arrProp
                }
    #footer
    New-UDParagraph -Text "This page was generated at $(Get-Date)"
    } #End UDPage ScriptBlock
        
#Create UDPage variable
New-Variable -Name ("UDPage" + $PageTitle -replace '\s') -Value (
    New-UDPage -Name $PageTitle -Content $scriptBlock
    )
