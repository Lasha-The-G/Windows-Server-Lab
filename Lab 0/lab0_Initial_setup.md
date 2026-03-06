# Lab Zero: Initial Setup
In this first part of the Windows Server Lab, I intend to finish a clean minimal setup in order to build on it in later labs.

These are the resources that we will need today:

| Host | Role | OS | IP | CPU | RAM |
|------|------|----|----|----|----|
| DC1 | Domain Controller | Windows Server 2022 Datacenter Core | 10.0.0.31 | 2 | 2GB |
| Client1 | Workstation | Windows 10 Pro | DHCP | 1 | 2GB |
Plus a virtual internal network switch **vSwitch** for the network 10.0.0.x/24

### Plan for today:
1. Deploy a **Windows Server 2022 Core VM** and do initial network configuration.
2. Install **Active Directory** and promote **DC1** to be a **Domain Controller**.
3. Install **DHCP** and configure a scope.
4. Create a basic **OU** structure paired with **Group Policy Objects**. 
6. Join a Workstation **Windows 10 Pro VM** to the domain, verify network configuration and **GPO** policies.
			


## 1. Installing windows server and initial configuration
### Windows Server installation:
Install windows server from a live CD installation media on DC1. 
Just fallow the intuitive installation instructions and set a strong administrator password.

### Network configuration:
This would be our network configuration on our server:

	IPv4 Address: 10.0.0.31
	Subnet Mask: 255.255.255.0
	Default Gateway: <blank>
	
	Prefered DNS server: 10.0.0.31
	Alternate DNS server: <blank>

We don't want our VMs to disrupt anyone on the host network. So our VMs are limited with communicaction with the **Host** and other **VMs** on the network using the internal **vSwitch**. Therefore default gateway is left blank.
Also DC1 will function as a DNS server so we set it's ip as prefered DNS.
>IPv6 is left enabled even though our lab primarily uses IPv4, because Active Directory services internally depend on IPv6.

To configure all of the above we can run the fallowing powershell script:
[DC1_network_configuration.ps1](https://github.com/Lasha-The-G/Windows-Server-Lab/blob/main/Lab%200/scripts/DC1_network_configuration.ps1)

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

	    Write-Host "Ethernet configuration succeeded"
	    Get-NetAdapter
	    exit 0
	}
	Write-Host "Ethernet configuration failed"


And to complete the initial setup, we also need to change server name to "DC1" before installing Active Directory.

	Rename-Computer -NewName DC1 -Restart 


## 2. Install and configure Active Directory

**DC1** with **Active Directory** will act as our centralized database for storing and managing network objects, like users computers and devices. New users will have to authenticate with **DC1** to join our internal **Domain** and access Domain specific resources.
>**Active directory** also comes with and requires DNS for domain controller discovery, kerberos authentication, and more. For our purposes AD DNS is already configured to maintain entries for all of our devices so we won't have to manually configure DNS.

To install AD DS role we can simply run:
	
	Install-WindowsFeature AD-Domain-Services -IncludeManagementTools 

And after this installation we need to create a new forest for our domain. 
To create the forest with our domain we can run:

	Import-Module ADDSDeployment
	Install-ADDSForest -DomainName "Corp.local" -InstallDNS
>"Corp.local" Domain name is arbitrary, we will only have to use "corp\username" for login or when joining the domain.

this command will require us to authenticate with our local administrator account, and ask us if we want to promote this server to be a domain controller and restart afterwards.
We want both so we input A:

	PS C:\Users\Administrator> Install-ADDSForest -DomainName "YourDomainName.com" -InstallDNS
	SafeModeAdministratorPassword: ************
	Confirm SafeModeAdministratorPassword: ************

	The target server will be configured as a domain controller and restarted when this operation is complete.
	Do you want to continue with this operation?
	[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "Y"): A


Or we can run this simple script for all of the above:
[DC1_AD_setup.ps1](https://github.com/Lasha-The-G/Windows-Server-Lab/blob/main/Lab%200/scripts/DC1_AD_setup.ps1)
	
	try{
	    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools 
	    Write-Host "AD DS installed successfully"
	} catch {
	    Write-Host "AD DS installation failed"
	    exit 0
	}

	$domainname = "corp.local"
	Import-Module ADDSDeployment
	Try{
	    Install-ADDSForest -DomainName $domainname -InstallDNS
	    Write-Host "AD DS Forest created successfully"
	} Catch {
	    Write-Host "AD DS Forest creation failed"
	    exit 0
	}


After the reboot, just to verify that AD DS was correctly installed and configured, we can run:
	
	Get-Service adws,kdc,netlogon,dns
Which displays:

	Status   Name               DisplayName
	------   ----               -----------
	Running  adws               Active Directory Web Services
	Running  dns                DNS Server
	Running  kdc                Kerberos Key Distribution Center
	Running  Netlogon           netlogon


## 3. Install DHCP and configure a scope

We need DHCP to automatically assign IPs to our client computers. 
So we install DHCP:

	Install-WindowsFeature DHCP -IncludeManagementTools

We want to tell **DHCP** to hand out **IPs** from **10.0.0.100** to **10.0.0.200**. 
For this we create a new scope:

	Add-DhcpServerv4Scope -Name "Sales-Office01" -StartRange 10.00.00.100 -EndRange 10.00.00.200 -SubnetMask 255.255.255.0

We also want connected devices to use **DC1** as a **DNS** server for internal network name resolution:

	Set-DhcpServerv4OptionValue -ScopeId 10.0.0.0 -DnsServer 10.0.0.31

And we need to **Activate** the scope And **Authorize** the server against other domain controllers in the domain 

	Set-DhcpServerv4Scope -ScopeId 10.0.0.0 -State Active
	Add-DhcpServerInDC -DnsName "DC1.corp.local" -IPAddress 10.0.0.31 

And now to see that **DHCP** is working we can run:
	
	Get-DhcpServerv4OptionValue -ScopeId 10.0.0.0 

Or run a simple script to do everything:
[DC1_DHCP_setup.ps1](https://github.com/Lasha-The-G/Windows-Server-Lab/blob/main/Lab%200/scripts/DC1_DHCP_setup.ps1)

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

## 4. Create an OU structure.

We want a clean Organizational Unit structure to simplify future user and computer administration using Group Policy Objects. 

We will fallow the fallowing structure:
- **corp.local**
  - **Sales (OU)**
    - **Sales-Users (OU)**
      - GPO: Sales-Users-Policy
      - **Sales-Users-Group (Security Group)**
        - Bob-Ross (User, member)
    - **Sales-Managers (OU)**

So we create a general Sales Organizational Unit under the domain
	
	New-ADOrganizationalUnit -Name "Sales" -Path "DC=corp,DC=local"

And two sub-OUs for regular Users and Managers:
	
	New-ADOrganizationalUnit -Name "Sales-Users" -Path "OU=Sales,DC=corp,DC=local"
	New-ADOrganizationalUnit -Name "Sales-Managers" -Path "OU=Sales,DC=corp,DC=local"

Now with this organizational structure we can add users and security groups. 

Just as an example we can create an User account for **Bob Ross** under **Sales-Users**. And enable it.

	New-ADUser -Name "Bob Ross" -SamAccountName "bross" -Path "OU=Sales-Users,OU=Sales,DC=corp,DC=local" -ChangePasswordAtLogon $true -Enabled $true
	$pass = Read-Host -AsSecureString
	Set-ADAccountPassword -Identity bross -NewPassword $pass
	Get-ADUser -Identity bross | Enable-ADAccount

We should also create a security group for sales users like Bob Ross:
>Because later we will create a file server with shared resources for sales users. And it is best to assign NTFS permissions to a group instead of individual users

	New-ADGroup -GroupScope Global -Name Sales-Users-Group -Path "OU=Sales-Users,OU=Sales,DC=corp,DC=local"
	Add-ADGroupMember -Identity Sales-Users-Group -Members bross

Now we can create a new Group Policy Object, and link it to Sales-Users OU

	New-GPO -Name Sales-Users-Policy -Comment "Sales-Users access and permissions" `
	| New-GPLink -Target "ou=Sales-Users,ou=Sales,dc=corp,dc=local"

Now all policies or preferences that we define in this GPO apply to all users under Sales-Users OU. 
Meaning if 10 people work in sales, instead of defining permissions individually, we just put them in this OU.

And just as an example let's set a default company wallpaper to all the sales users 
>It's implied that i created a made a shared directory under the root of our DC1 where i put the image. But that's off topic from OUs and GPOs.

	$GPO = "Sales-Users-Policy"
	Set-GPRegistryValue -Name $GPO `
	    -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
	    -ValueName "Wallpaper" `
	    -Type String `
	    -Value "\\DC1\wallpapers\sales.jpg"

## 5. Join a client workstation to the domain

Now we want to verify all of our configuration.

So we create another **VM** in **Hyper-V** for a client and fallow installation media instructions to install **Windows 10 Pro**. 
>Aside for Hyper-V users:
>When using Hyper-V to join a non-admin, we need to disable the enhanced session for the client VM after startup. Otherwise we would have to add the user to Remote Desktop Users group.

After we sign in on the client, we need to join it to our corp.local domain
We go to 
	
	Advanced System Settings > Computer name > "Network ID" 
And provide credentials of Bob Ross.

Now, after the client restarts, we can see that DHCP has correctly configured this computer
<Image of network configuration>
![client-dhcp-config](https://github.com/Lasha-The-G/Windows-Server-Lab/blob/main/Lab%200/screenshots/client-dhcp-configuration.png)
And The default wallpaper was applied. Yes, it's a black image.
<image of the wallpaper>
![gpo_default-wallpaper](https://github.com/Lasha-The-G/Windows-Server-Lab/blob/main/Lab%200/screenshots/gpo_default_wallpaper.png)


### This concludes the first part of my Windows Server Lab.

## Plans for the future lab:
Configure a simple file server, set **NTFS** permissions for **Security Group** based access, set quotas, file screening, drive mapping with GPOs. Perhaps even a storage pool or a SAN.

## After that:
Powershell automation and scripting for common administrative tasks: User creation and group placement. and resource usage mointoring and alerts.




