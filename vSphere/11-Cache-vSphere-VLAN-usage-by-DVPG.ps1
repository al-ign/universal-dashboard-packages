$EndPointName = 'VLANUsageByDV'
New-Variable -Name ("UDEndPoint" + $EndPointName -replace '\s') -Value (
    New-UDEndpoint -Id $EndPointName -Schedule $udSchedule30min -Endpoint {
        
        if ($Cache:ViServer.Name) {
            Connect-VIServer -Server $Cache:ViServer.Name -Session $Cache:ViServer.SessionSecret
            }
        else {
            Connect-VIServer -Server $UDEPVarViServerList
            }
    
        $cache:ude_vlan_pwd = $pwd
        #Loading view
        $view =  @( get-view -ViewType DistributedVirtualPortgroup -Property Name, Config, VM | Select-Object Name, Config, VM, MoRef)
        if ($view) {
        
            #load ignore list, if available
            $Config_SkipDVPGNames = (Join-Path  (Join-Path $cache:DashboardRootPath 'Config') 'config_SkipDVPGNames.json' )
            if (Test-Path $Config_SkipDVPGNames -ea 0) {
                try {
                    $SkipDVPGNames = Get-Content $Config_SkipDVPGNames | ConvertFrom-Json 
                    }
                catch {
                    $SkipDVPGNames = @()
                    }
                }

            $VlanUsageByDS = foreach ($thisDVPG in $view ) {
                if ($SkipDVPGNames -contains $thisDVPG.name ) {
                    #this entry is in the ignore list, skipping
                    }
                else {
                    foreach ($VID in @($thisDVPG.Config.DefaultPortConfig.Vlan.VlanId) )  {
                        #if this is a range - spit out every VID as separate object
                        if ($VID -is [VMware.Vim.NumericRange]) {
                            $VID.start..$VID.end | % {
                                [pscustomobject][ordered]@{                         
                                    VLAN = [int]$_
                                    Name = [string]$thisDVPG.name
                                    VM = ($thisDVPG.vm).Count
                                    MoRef = $thisDVPG.MoRef.ToString()
                                    }
                                }
                            }
                        else {
                            [pscustomobject][ordered]@{ 
                                VLAN = [int]$VID
                                Name = [string]$thisDVPG.name 
                                VM = ($thisDVPG.vm).Count
                                MoRef = $thisDVPG.MoRef.ToString()
                                }
                            }
                        }
                    }
                }

            $Cache:VLANUsageByDVPG = $VlanUsageByDS | Sort-Object VLAN
            $Cache:VLANUsageByDVPGLastUpdate = Get-Date
            $Cache:VLANUsageByDVPGUniqueVLAN = ($VlanUsageByDS | select VLAN -Unique | Sort-Object VLAN).Count
            $Cache:VLANUsageByDVPGUniqueDVPG = ($VlanUsageByDS | select Name -Unique).Count
            $Cache:VLANUsageByDVPGSkippeDVPG = ($SkipDVPGNames).Count

            }#End view

        }#End UDEndPoint
)#End Variable Creation
