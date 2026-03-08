try{
    Install-WindowsFeature DHCP -IncludeManagementTools -ErrorAction Stop
    Write-Host "DHCP installation succeeded"
} catch {
    Write-Host "DHCP installation failed $($_.Exception.Message)"
    exit 1
}
try{
    Add-DhcpServerv4Scope -Name "Sales-Office01" -StartRange 10.00.00.100 -EndRange 10.00.00.200 -SubnetMask 255.255.255.0 -ErrorAction Stop
    Set-DhcpServerv4OptionValue -ScopeId 10.0.0.0 -DnsServer 10.0.0.31 -ErrorAction Stop
    Set-DhcpServerv4Scope -ScopeId 10.0.0.0 -State Active -ErrorAction Stop
    Add-DhcpServerInDC -DnsName "DC1.corp.local" -IPAddress 10.0.0.31 -ErrorAction Stop
    Write-Host "DHCP configuration succeeded"
} catch {
    Write-Host "DHCP configuration failed: $($_.Exception.Message)"
    exit 1
}
