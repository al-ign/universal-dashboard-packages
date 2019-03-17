$PageTitle = 'vSphere Snapshots Status'


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

    filter Recurse-Snapshots {
        $snap = $_ 
        $snap
        foreach ($thisSnap in $snap.childSnapshotList) {
            $thisSnap | Recurse-Snapshots
            }
        }

    if ($Cache:ViServer.Name) {
        Connect-VIServer -Server $Cache:ViServer.Name -Session $Cache:ViServer.SessionSecret
        }
    else {
        Connect-VIServer -Server $UDEPVarViServerList
        }
    
    $view = Get-View -ViewType VirtualMachine -Filter @{Snapshot=''} -Property Name, Parent, Snapshot, ResourcePool -ErrorAction 0

    if ($view) {
        
        $dt = (get-date)
        $snaps = foreach ($Vm in $view) {
            $vm.Snapshot.RootSnapshotList | Recurse-Snapshots |  % {
                [pscustomobject][ordered]@{
                    Name = $vm.name
                    SnapshotName = $_.name
                    Description = $_.Description
                    CreateTime = $_.CreateTime
                    Age = [int]([math]::Round(($dt - $_.CreateTime[0]).TotalDays))
                    Parent = $vm.Parent #| Get-ViName
                    ResPool = $vm.ResourcePool #| Get-ViName
                    MoRef = $vm.MoRef
                    }
                }
            }

        $snapsUnique = $snaps.MoRef | Select-Object -Unique

        $snapsStats = foreach ($thisSnap in $snapsUnique) {
            $select = @($snaps | ? MoRef -eq $thisSnap | Sort-Object Age)
            [pscustomobject][ordered]@{
                Name = $select[0].Name
                SnapCount = $select.Count
                Newest = ($select[0]).Age
                Oldest = ($select[$select.GetUpperBound(0)]).Age
                MoRef = $select[0].MoRef
                }
            }

        $tableSnapStats = {
            $arrProp = 'Name SnapCount Newest Oldest' -split ' '
            New-UDTable -Title 'Snapshot Stats' `
                -Headers $arrProp `
                -ArgumentList @($arrProp,$snapsStats) `
                -Endpoint {
                    $arrProp = $ArgumentList[0]
                    $ArgumentList[1] | % { 
                        $_.Name =  New-UDLink -Text ($_.Name) -Url ('/vSphere VM Info/' + $_.MoRef.ToString())
                        $_ } | Out-UDTableData -Property $arrProp
                    }
            }
        $tableSnapList = {
            $arrProp = 'Name SnapshotName Description CreateTime Age' -split ' '
            New-UDTable -Title 'Snapshot List' `
                -Headers $arrProp `
                -ArgumentList @($arrProp,$snaps) `
                -Endpoint {
                    $arrProp = $ArgumentList[0]
                    $ArgumentList[1] | % { 
                        $_.Name =  New-UDLink -Text ($_.Name) -Url ('/vSphere VM Info/' + $_.MoRef.ToString())
                        $_ } | Out-UDTableData -Property $arrProp
                    }
            }
        & $tableSnapStats
        & $tableSnapList
        }
    else {
        New-UDCard -Title 'Nope' -Content {
            New-UDParagraph -Text ('Nothing found')
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
