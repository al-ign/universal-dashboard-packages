$PageTitle = 'vSphere Resource Pool Info'
$PageParameter = 'PageParameter'

#Create UDPage Endpoint
$scriptBlock = {
    param (
        $PageParameter
        )

    New-UDInput -Title "Search" -SubmitText 'Find' -Endpoint {
        param( $PageParameter )
        New-UDInputAction -RedirectUrl ('/{0}/{1}' -f $PageTitle, $PageParameter)
        }

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

filter Convert-ResourcePoolLimits {

    if ($_.Config.CpuAllocation.Limit -eq -1) {
        $cpuLimit = 'Unlimited'
        }
    else {
        $cpuLimit = "{0} MHz" -f $_.Config.CpuAllocation.Limit
        }

    if ($_.Config.MemoryAllocation.Limit -eq -1) {
        $ramLimit = 'Unlimited'
        }
    else {
        $ramLimit = "{0} Mb" -f $_.Config.MemoryAllocation.Limit
        }
    
    [pscustomobject][ordered]@{
        CPU = [string]( "CPU Usage/Limit {0} MHz / {1}" -f $_.Runtime.Cpu.OverallUsage, $cpuLimit )
        RAM = [string]( "RAM Usage/Limit {0} Mb / {1}" -f ($_.Runtime.Memory.OverallUsage / 1mb | Round-Value),$ramLimit )
        }
 
    }

    if ($PageParameter -match 'ResourcePool-resgroup-\d+') {
        $ResourcePool = Get-View -Id $PageParameter -Property Name, Owner, Parent, Config, Summary, Runtime, VM -ErrorAction SilentlyContinue | ? VM
        }
    else {
        $ResourcePool = Get-View -ViewType ResourcePool -Filter @{Name=$PageParameter} -Property Name, Owner, Parent, Config, Summary, Runtime, VM -ErrorAction SilentlyContinue | ? VM
        }

    #$ResourcePool = Get-View -ViewType ResourcePool -Filter @{Name=$PageParameter} | ? VM
    if ($ResourcePool) {
        $ResourcePoolFiltered = foreach ($thisResourcePool in $ResourcePool) {
            [pscustomobject][ordered]@{
                Name = $thisResourcePool.name
                Owner = $thisResourcePool.Owner | Get-ViName
                Config = $thisResourcePool.Config
                Runtime = $thisResourcePool.Runtime
                Summary = $thisResourcePool.Summary
                VM = $thisResourcePool.Vm
                MoRef = $thisResourcePool.MoRef
                }
            }

        foreach ($thisResourcePool in $ResourcePoolFiltered) {
            New-UDCard -Title ($thisResourcePool.Name + ', ' + $thisResourcePool.Owner) -Content {
                New-UDLayout -Columns 4 -Content {
                    New-UDParagraph -Content {
                        New-UDLink -Text 'View pool' -Url ('/vSphere Resource Pool Info/' + $thisResourcePool.MoRef.ToString()) 
                        }
                    New-UDParagraph -Text ($thisResourcePool | Convert-ResourcePoolLimits).CPU
                    New-UDParagraph -Text ($thisResourcePool | Convert-ResourcePoolLimits).RAM
                    New-UDParagraph -Text (
                        "Swap: {0} Mb  |  Balloon: {1} Mb" -f `
                        $thisResourcePool.Summary.QuickStats.SwappedMemory,
                        $thisResourcePool.Summary.QuickStats.BalloonedMemory
                        #>
                        )
                    }

                $arrProp = 'On', 'Name','IpAddress','View','Diag' 
                New-UDTable -Headers $arrProp `
                    -ArgumentList @($arrProp,$thisResourcePool) `
                    -Endpoint {
                        $arrProp = $ArgumentList[0]
                        $ArgumentList[1].vm | % {
                            $child = $_
                            $cache:VMList.Where({$_.MoRef -eq $child.ToString()})
                            } `
                            | Select-Object `
                            @{N='On';E={ 
                                if ($_.PowerState -eq 'poweredOn') {
                                    New-UDHtml -Markup $('<font color="DarkGreen">' + '☼' + '</font>')
                                    }
                                }},
                            Name, 
                            IpAddress, 
                            @{N='View';E={New-UDLink -Text 'View' -Url ('/vSphere VM Info/' + $child.ToString())}},
                            @{N='Diag';E={New-UDLink -Text 'View' -Url ('/vSphere VM Diag/' + $child.ToString())}} `
                            | Out-UDTableData -Property $arrProp
                        }
            
                }#End UDCard
        
            }#End %
        }#End if ResourcePool
    else {
        New-UDParagraph -Text ('No results for ' + $PageParameter )
        }
    New-UDParagraph -Text ('This page was generated at ' + (Get-date) )
    } # End UDPage 

#Create proper URL depending on PageParameter
if ($PageParameter.Length -gt 0) {
    $PageUrl = '/{0}/:{1}/' -f $PageTitle, $PageParameter #-replace '\s','-'
    }
else {
    $PageUrl = '/{0}' -f $PageTitle #-replace '\s','-'
    }

#Create UDPage variable
New-Variable -Name ("UDPage" + $PageTitle -replace '\s') -Value (
    New-UDPage -Url $PageUrl -Endpoint $scriptBlock
    )
