New-ADOrganizationalUnit -Name "Sales" -Path "DC=corp,DC=local"

New-ADOrganizationalUnit -Name "Sales-Users" -Path "OU=Sales,DC=corp,DC=local"
New-ADOrganizationalUnit -Name "Sales-Managers" -Path "OU=Sales,DC=corp,DC=local"

New-ADUser -Name "Bob Ross" -SamAccountName "bross" -Path "OU=Sales-Users,OU=Sales,DC=corp,DC=local" -ChangePasswordAtLogon $true -Enabled $true
$pass = Read-Host -AsSecureString
Set-ADAccountPassword -Identity bross -NewPassword $pass
Get-ADUser -Identity bross | Enable-ADAccount

New-ADGroup -GroupScope Global -Name Sales-Users-Group -Path "OU=Sales-Users,OU=Sales,DC=corp,DC=local"
Add-ADGroupMember -Identity Sales-Users-Group -Members bross

New-GPO -Name Sales-Users-Policy -Comment "Sales-Users access and permissions" `
| New-GPLink -Target "ou=Sales-Users,ou=Sales,dc=corp,dc=local"

#$GPO = "Sales-Users-Policy"
#Set-GPRegistryValue -Name $GPO `
#    -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
#    -ValueName "Wallpaper" `
#    -Type String `
#    -Value "\\DC1\wallpapers\sales.jpg"