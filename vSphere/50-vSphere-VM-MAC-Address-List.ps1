$PageTitle = 'vSphere VM MAC Address List'


#Create UDPage Endpoint
$scriptBlock = {
    #Your content here

    New-UDParagraph -Text 'This is a cached search. List is updated every 30 minutes'
    New-UDParagraph -Text ('Records in the list: ' + ($Cache:VMMacAddress).Count)

    $arrProp = 'Name', 'MacAddress', 'Connected', 'View'
    New-UDGrid -Title 'Search VM by MAC' -Headers $arrProp -Properties $arrProp -Endpoint  {
        $Cache:VMMacAddress  | select Name, MacAddress, Connected,
            @{N='View';E={New-UDLink -Text "View" -Url ('/vSphere VM Info/' + $_.Moref)}} | Out-UDGridData

        }#End UDGrid

    #footer
    New-UDParagraph -Text "This page was generated at $(Get-Date)"
    } #End UDPage ScriptBlock


#Create proper URL
$PageUrl = '/{0}' -f $PageTitle #-replace '\s','-'

#Create UDPage variable
New-Variable -Name ("UDPage" + $PageTitle -replace '\s') -Value (
    New-UDPage -Url $PageUrl -Endpoint $scriptBlock
    )
