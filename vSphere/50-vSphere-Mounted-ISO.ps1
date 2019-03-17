$PageTitle = 'vSphere Mounted ISO'


#Create UDPage Endpoint
$scriptBlock = {
    #Your content here
    function Get-ViName {
        [CmdletBinding()]
        [OutputType([string])]
        Param (        
            [Parameter(Mandatory=$true,
                       ValueFromPipeline=$true,
                       Position=0)]
            $Object
            )
        Process {
            (get-view -Id $Object -Property Name).Name
            }
        }

    if ($Cache:ViServer.Name) {
        Connect-VIServer -Server $Cache:ViServer.Name -Session $Cache:ViServer.SessionSecret
        }
    else {
        Connect-VIServer -Server $UDEPVarViServerList
        }
    
    $view = @(Get-View -ViewType VirtualMachine -Property Name,Parent,'Config.Hardware.Device')    
    
    if ($view) {
        $ISOList = foreach ($vm in $view) {

            $cdrom = @( $VM.Config.Hardware.Device | ? {$_ -is [VMware.Vim.VirtualCdrom]} | ? {$_.Connectable.Connected})

            foreach ($thisCDROM in $cdrom) {
                [pscustomobject][ordered]@{
                    Name = $vm.Name
                    FileName = $thisCDROM.Backing.FileName
                    MoRef = $vm.MoRef
                    }
                }
            }

            $tableISOList = {
                $arrProp = 'Name Filename' -split ' '
                New-UDTable -Title 'Mounted ISO List' `
                    -Headers $arrProp `
                    -ArgumentList @($arrProp,$ISOList) `
                    -Endpoint {
                        $arrProp = $ArgumentList[0]
                        $ArgumentList[1] | % { 
                            $_.Name =  New-UDLink -Text ($_.Name) -Url ('/vSphere VM Info/' + $_.MoRef.ToString())
                            $_ } | Out-UDTableData -Property $arrProp
                        }
            }
        if ($ISOList) {
            & $tableISOList
            }
        else {
            New-UDCard -Title 'Success?' -Content {
                New-UDParagraph -Text ('Query was succesful, but no mounted ISO was found')
                }
            }
        }
    else {
        New-UDCard -Title 'Fail' -Content {
            New-UDParagraph -Text ('Query was empty or failed')
            }
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
