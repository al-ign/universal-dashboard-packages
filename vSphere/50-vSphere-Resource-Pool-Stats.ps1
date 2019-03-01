$PageTitle = 'vSphere Resource Pool Stats'


#Create UDPage Content
$scriptBlock = {
    
    if ($Cache:ViServer.Name) {
        Connect-VIServer -Server $Cache:ViServer.Name -Session $Cache:ViServer.SessionSecret
        }
    else {
        Connect-VIServer -Server $UDEPVarViServerList
        }

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

    #$ResourcePool = Get-View -ViewType ResourcePool -Property Name, Runtime, Summary, Parent -ErrorAction SilentlyContinue 
    $ResourcePool = Get-View -ViewType ResourcePool -Property Name, Runtime, Summary, Parent -ErrorAction SilentlyContinue  | ? { ($_.Summary.QuickStats.SwappedMemory -ne 0) -or ($_.Summary.QuickStats.BalloonedMemory -ne 0) }
    $ResourcePool = foreach ($thisPool in $ResourcePool) {
        [PSCustomObject][ordered]@{
            Name = $thisPool.Name 
            CpuOverallUsage = $thisPool.Runtime.Cpu.OverallUsage
            CpuMaxUsage = $thisPool.Runtime.Cpu.MaxUsage
            CpuEq = $thisPool.Runtime.Cpu.OverallUsage -eq $thisPool.Runtime.Cpu.MaxUsage
            MemoryOverallUsage = $thisPool.Runtime.Memory.OverallUsage
            MemoryMaxUsage = $thisPool.Runtime.Memory.MaxUsage
            MemoryEq = $thisPool.Runtime.Memory.OverallUsage -eq $thisPool.Runtime.Memory.MaxUsage
            SwappedMemory = $thisPool.Summary.QuickStats.SwappedMemory
            BalloonedMemory = $thisPool.Summary.QuickStats.BalloonedMemory
            ParentName = [string]($thisPool.Parent | Get-ViName)
            ParentMoRef = $thisPool.Parent.ToString()
            MoRef = $thisPool.MoRef
            }
        }

    $ResourcePoolFiltered = $ResourcePool
    if ($ResourcePoolFiltered) {
            New-UDCard -Title ('Resource Pools with Ballooned and/or Swapped memory') -Content {
                New-UDLayout -Columns 3 -Content {
                    New-UDParagraph -Text ("Overprovisioned pools: {0}" -f $ResourcePoolFiltered.Count)
                    New-UDParagraph -Text ("Total Ballooned: {0} Mb" -f ($ResourcePoolFiltered.balloonedMemory | Measure-Object -Sum).Sum)
                    New-UDParagraph -Text ("Total Swapped: {0} Mb" -f ($ResourcePoolFiltered.SwappedMemory | Measure-Object -Sum).Sum)
                    }

                $arrProp = 'Name','SwappedMemory','BalloonedMemory','CpuMaxUsage', 'MemoryMaxUsage', 'Parent', 'View'
                New-UDTable -Headers $arrProp `
                    -ArgumentList @($arrProp,$ResourcePoolFiltered) `
                    -Endpoint {
                        $arrProp = $ArgumentList[0]
                        $ArgumentList[1] | % {
                            $_ | Select-Object Name, 
                            SwappedMemory,
                            BalloonedMemory,
                            CpuMaxUsage,
                            @{N='MemoryMaxUsage';E={'{0} Mb' -f ($_.MemoryMaxUsage / 1Mb | Round-Value)}},
                            @{N='Parent';E={New-UDLink -Text $_.ParentName -Url ('/listpool/' + $_.ParentMoRef)}},
                            @{N='View';E={New-UDLink -Text 'View' -Url ('/listpool/' + $_.MoRef.ToString())}} `
                            | Out-UDTableData -Property $arrProp
                        }
                    }#End UDTable
            
                }#End UDCard

        }#End if ResourcePool
    else {
        New-UDParagraph -Text ('There is no Resource Pools with Ballooned and/or Swapped memory in {0} pools' -f $ResourcePool.Count )    
        }
    New-UDParagraph -Text ('This data is queried online')
    #footer
    New-UDParagraph -Text "This page was generated at $(Get-Date)"
    } #End UDPage ScriptBlock

#Create a proper URL
$PageUrl = '/{0}' -f $PageTitle #-replace '\s','-'

#Create UDPage variable
New-Variable -Name ("UDPage" + $PageTitle -replace '\s') -Value (
    New-UDPage -Url $PageUrl -Endpoint $scriptBlock
    )

