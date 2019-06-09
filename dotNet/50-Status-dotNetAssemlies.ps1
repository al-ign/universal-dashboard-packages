$PageTitle = 'Status dotNet Assemblies'

$PageDescription = 'Display dotNET assemblies loading status'

#Create UDPage Endpoint
$scriptBlock = {
    #Your content here
    New-UDParagraph -Text (
        '$cache:assemblyLoadResults count: {0}' -f ($cache:assemblyLoadResults).Count
        )
    
    New-UDGrid -Title 'Assemblies' -Endpoint {
        $cache:assemblyLoadResults | Out-UDGridData
        }
    
    #footer
    New-UDParagraph -Text "This page was generated at $(Get-Date)"
    } #End UDPage ScriptBlock


#Create proper URL
$PageUrl = '/{0}' -f $PageTitle -replace '\s'

#Create UDPage variable
New-Variable -Name ("UDPage" + $PageTitle -replace '\s') -Value (
    New-UDPage -Url $PageUrl -Endpoint $scriptBlock
    )
