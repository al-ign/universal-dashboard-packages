$PageTitle = 'vSphere VM with USB Devices'


#Create UDPage Endpoint
$scriptBlock = {
    #Your content here
    if ($Cache:ViServer.Name) {
        Connect-VIServer -Server $Cache:ViServer.Name -Session $Cache:ViServer.SessionSecret
        }
    else {
        Connect-VIServer -Server $UDEPVarViServerList
        }
    
    $view = Get-View -Property Name, Config, Parent -ViewType VirtualMachine
    $USB = foreach ($thisVM in $view) {
        if ($thisVM.Config.Hardware.Device | ? {$_ -is [VMware.Vim.VirtualUSB]}) {
            foreach ($thisUSB in @($thisVM.Config.Hardware.Device | ? {$_ -is [VMware.Vim.VirtualUSB]})) {

                [PSCustomObject]@{
                    Uuid = $thisVM.Config.Uuid
                    Name = $thisVM.Name 
                    Parent = $thisVM.Parent
                    Folder = $thisVM.Parent | Get-ViName
                    Label = $thisUSB.DeviceInfo.Label
                    DeviceInfo = $thisUSB.DeviceInfo.Summary
                    Backing = $thisUSB.Backing.DeviceName
                    }
                }
            }
        }
    if ($USB) {
        $arrProp = @('Name','Folder','Label','DeviceInfo','Backing')

        New-UDTable -Title $PageTitle `
                -Headers $arrProp `
                -ArgumentList @($arrProp,$USB) `
                -Endpoint {
                    $arrProp = $ArgumentList[0]
                    $USB = $ArgumentList[1]
                    #$USB | % {$_.name = New-UDLink -Text $_.Name -Url ('/vSphere VM Info/' + $_.MoRef.Value)} | Select-Object $arrProp |  Out-UDTableData -Property $arrProp
                    $USB | Select-Object $arrProp |  Out-UDTableData -Property $arrProp
                    }
        }
    Else {
        New-UDCard -Text 'No VMs with USB Devices was found'
        }

    #footer
    New-UDParagraph -Text "This page was generated at $(Get-Date)"
    } #End UDPage ScriptBlock


#Create proper URL
$PageUrl = '/{0}' -f $PageTitle #-replace '\s'

#Create UDPage variable
New-Variable -Name ("UDPage" + $PageTitle -replace '\s') -Value (
    New-UDPage -Url $PageUrl -Endpoint $scriptBlock
    )
