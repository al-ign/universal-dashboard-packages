$PageTitle = 'vSphere VM List'

#Create UDPage Content
$scriptBlock = {
    #Your content here
    
    New-UDParagraph -Text ('This is a cached search. List is updated every 5 minutes. Last update: ' + $Cache:VMListTimeStamp)
    New-UDParagraph -Text ('Records in the list: ' + ($Cache:VMCount))

    $arrProp = 'Name', 'PowerState', 'IpAddress'
    New-UDGrid -Title 'Search VM by name or IP address' -Headers $arrProp -Properties $arrProp -Endpoint  {
        $Cache:VMList  | select @{N='Name';E={New-UDLink -Text $_.Name -Url ('/vminfo/' + $_.Moref)}}, PowerState, IpAddress | Out-UDGridData

        }#End UDGrid

    #footer
    New-UDParagraph -Text "This page was generated at $(Get-Date)"
    } #End UDPage ScriptBlock

#Create a proper URL
$PageUrl = '/{0}' -f $PageTitle  #-replace '\s','-'

#Create UDPage variable
New-Variable -Name ("UDPage" + $PageTitle -replace '\s') -Value (
    New-UDPage -Url $PageUrl -Endpoint $scriptBlock
    )

#Get-Variable ("UDPage" + $PageTitle -replace '\s') -ValueOnly | Add-Member -NotePropertyName PageTitle -NotePropertyValue $PageTitle