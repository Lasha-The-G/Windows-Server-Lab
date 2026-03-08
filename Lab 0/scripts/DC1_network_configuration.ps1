$interface_name = "Ethernet"
$ethernet_index = (Get-NetAdapter -Name $interface_name).ifIndex;
if ($ethernet_index -ge 1){
    New-NetIPAddress -IPAddress 10.0.0.31 `
				     -PrefixLength 24 `
				     -InterfaceIndex $ethernet_index `
				     | Out-Null
    Set-DnsClientServerAddress -InterfaceIndex $ethernet_index `
					 -ServerAddresses 10.0.0.31 `
					 | Out-Null
    Disable-NetAdapterBinding -Name $interface_name `
				     -ComponentID ms_tcpip6 `
				     | Out-Null
    Get-NetAdapter
    Write-Host "Ethernet configuration succeeded. The computer will restart shortly."
    Rename-Computer -NewName DC1 -Restart 
    exit 0
}
Write-Host "Ethernet configuration failed"
