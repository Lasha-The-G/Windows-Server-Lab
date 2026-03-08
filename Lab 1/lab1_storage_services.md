# Lab One: Storage Services (Under Construction)
In this part of my windows server lab i intend to build a simple file storage service for sharing documents between sales users, delegate permissions and make it easely accessable by our users.

### The resources that we will need today:
Our setup from the past lab:
Virtual internal network switch **vSwitch** for the network **10.0.0.x/24**
| Host | Role | OS | IP | CPU | RAM |
|------|------|----|----|----|----|
| DC1 | Domain Controller | Windows Server 2022 Datacenter Desktop Experience | 10.0.0.31 | 2 | 2GB |
| Client1 | Workstation | Windows 10 Pro | DHCP | 1 | 2GB |


A new server for storage services

| Host | Role | OS | IP | CPU | RAM |
|------|------|----|----|----|----|
| FILE1 | File Server | Windows Server 2022 Datacenter Core | 10.0.0.32 | 1 | 2GB | 

Plus multiple virtual hard drives.

>As of now we are more or less eyeballing the required system resources. In the next lab we will set up performance and resource monitoring and we will determine how much resources we actually need.

### Plan for today:
1. Set up **FILE1** with Windows Server and file server Roles
2. Set up a **Storage Pool** for large cheap storage
3. Set **NTFS** permissions and **Sharing**
4. Set **Quotas** and **file screening**

And verify the configuration on every step

## 1. Set up FILE1 with windows server and file server Roles

Fallow simple instructions of the installation medium in order to install windows server core. 

### Configure IP
For us to join our domain from FILE1, we need to configure the static ip with the same subnet. Otherwise VMs won't be able to reach each other

Find the IPv4 network interface index (not loopback) when running:

	Get-NetIPAddress

And set the new IP:
	
	New-NetIPAddress -InterfaceIndex <IPv4 interface idx> -IPAddress 10.0.0.32 -PrefixLength 24
	Set-DnsClientServerAddress -InterfaceIndex <IPv4 interface idx>

Rename the computer and restart to take effect:

	Rename-Computer -NewName "FILE1" -Restart

Now we will be able to join the domain through **SConfig**. We will just provide our administrator credentials and we are in.

Install roles required for this lab
	
	Install-WindowsFeature FS-FileServer -IncludeManagementTools
	Install-WindowsFeature FS-Resource-Manager -IncludeManagementTools
	Install-WindowsFeature FS-Data-Deduplication -IncludeManagementTools

## 2. Set up a Storage Pool

With a storage pool we will be able to take multiple hard drives and combine them to get a combined storage pool. We will be using RAID-0 or Simple memory layout because it both combines storage of our drives, and substantially increases throughput (due to concurrently writing to multiple drives. Which would really help with old and cheap hard drives).

On real servers storage often lives on separate controllers, and to mimic that, on **FILE1 VM** settings we will create two Hard Drives with their own SCSI controllers.

First we need to get the list of all the virtual hard disks except the C disk to create our storage pool

	$PhysicalDisks = (Get-PhysicalDisk -CanPool $true)

And create the storage pool

	New-StoragePool -FriendlyName "CompanyData" -StorageSubsystemFriendlyName "Windows Storage*" -PhysicalDisks $PhysicalDisks 

Now, using this storage pool we can create virtual drives that behave like regular hard drives. But the neat part is that the size of these virtual drives can exceed the size of individual drives.
Just to demonstrate this in our example we will create two virtual drives of 10GB and 20GB.

	New-VirtualDisk -StoragePoolFriendlyName CompanyData -FriendlyName vDrive1 -Size 10GB -ResiliencySettingName Simple
	New-VirtualDisk -StoragePoolFriendlyName CompanyData -FriendlyName vDrive2 -Size 20GB -ResiliencySettingName Simple

Now if we run "Get-Disk", we can see that from our two 15 gig drives we got a 10 and 20 gb drive

	Number Friendl Serial Number                    HealthStatus         OperationalStatus      Total Size Partition
	       y Name                                                                                          Style
	------ ------- -------------                    ------------         -----------------      ---------- ----------
	0      Msft...                                  Healthy              Online                      30 GB GPT
	3      vDrive1 {daa133a2-0d77-4281-8fec-7d36... Healthy              Offline                     10 GB RAW
	4      vDrive2 {e3b34567-18e5-4675-b40a-96b8... Healthy              Offline                     20 GB RAW

Now we can bring these drives online, partition and format them to our liking.

	Initialize-Disk -Number 3 -PartitionStyle GPT  #Bring drive online
	New-Partition -DiskNumber 3 -UseMaximumSize -AssignDriveLetter #Create one partition from the drive
	#OS assigned this drive partition the letter E
	Format-Volume -DriveLetter E -FileSystem NTFS -NewFileSystemLabel "Drive1"  

And do the same for the second drive

	Initialize-Disk -Number 4 -PartitionStyle GPT
	New-Partition -DiskNumber 4 -UseMaximumSize -AssignDriveLetter
	Format-Volume -DriveLetter F -FileSystem NTFS -NewFileSystemLabel "Drive2"

Which leaves us with two available virtual disks to use for our file server purposes

	PS F:\> get-volume

	DriveLetter FriendlyName          FileSystemType DriveType HealthStatus OperationalStatus SizeRemaining
	----------- ------------          -------------- --------- ------------ ----------------- -------------
	                                  NTFS           Fixed     Healthy      OK                     81.53 MB
	D           SSS_X64FREE_EN-US_DV9 Unknown        CD-ROM    Healthy      OK                          0 B
	E           Drive1                NTFS           Fixed     Healthy      OK                      9.44 GB
	C                                 NTFS           Fixed     Healthy      OK                     22.68 GB
	F           Drive2                NTFS           Fixed     Healthy      OK                     19.42 GB
	                                  FAT32          Fixed     Healthy      OK                     68.26 MB



## 3. Set NTFS permissions and Sharing

### NTFS permissions:
Here we will set up a shared directory for our sales reports and give sales users permissions to access documents and portable applications inside.
If we run get-volume we will be able to see letters assigned to our virtual drives. 

	E           Drive1                NTFS           Fixed     Healthy      OK                      9.44 GB
	F           Drive2                NTFS           Fixed     Healthy      OK                     19.42 GB

We will create our sales reports directory under F

	New-Item -Path "F:\" -Name "Sales-Reports" -ItemType "Directory"

And create an access control entry for our sales-users. which we have to build piece by piece.

	$identity = 'CORP\Sales-Users-Group'
	$rights = 'ReadAndExecute' #Other options: [enum]::GetValues('System.Security.AccessControl.FileSystemRights')
	$inheritance = 'ContainerInherit, ObjectInherit' # Our of our scope
	$propagation = 'None' # Our of our scope
	$type = 'Allow' #Other options: [enum]::GetValues('System.Securit y.AccessControl.AccessControlType')
	$ACE = New-Object System.Security.AccessControl.FileSystemAccessRule($identity,$rights,$inheritance,$propagation, $type)

Add our access control entrie to the access control list of Sales-Reports.
	
	$ACL = Get-Acl F:\Sales-Reports\
	$ACL.AddAccessRule($ACE)

And actually set the new ACL on Sales-Reports

	Set-Acl F:\Sales-Reports\ -AclObject $ACL

Finaly, we can verify that all of this worked:

	PS F:\> (Get-Acl F:\Sales-Reports\).Access | Format-Table

	           FileSystemRights AccessControlType IdentityReference      IsInherited       InheritanceFlags
	           ---------------- ----------------- -----------------      -----------       ----------------
	                FullControl             Allow BUILTIN\Administrators       False                   None
	ReadAndExecute, Synchronize             Allow CORP\Sales-Users-Group       False ...erit, ObjectInherit
	                FullControl             Allow BUILTIN\Administrators        True ...erit, ObjectInherit
	                FullControl             Allow NT AUTHORITY\SYSTEM           True ...erit, ObjectInherit
	                  268435456             Allow CREATOR OWNER                 True ...erit, ObjectInherit
	ReadAndExecute, Synchronize             Allow BUILTIN\Users                 True ...erit, ObjectInherit
	                 AppendData             Allow BUILTIN\Users                 True       ContainerInherit
	                CreateFiles             Allow BUILTIN\Users                 True       ContainerInherit

As we can see Sales-Users-Group with all of our sales users has Read and Execute permissions to Sales-Reports resources. 


## Sharing:

Now the neat part about shared drives is that when deciding between NTFS and Share access, it always choses the lowest access. Meaning: If share is set to give full access (highest access) then whatever NTFS setting you chose, it's always going to be lower then full access, and NTFS access settings will be used.
Therefore it's best to correctly set your NTFS permissions and then grant Full access in Shares. Which is the microsoft recommended approach.

	New-SmbShare -Name "Sales-Reports" -Path "F:\Sales-Reports\" -FullAccess "CORP\Administrator","CORP\Sales-Users-Group"


Finally, we can verify shared access at \\\FILE1\Sales-Reports from our Client1 VM 
Bob Ross would need to provide his credentials 
<Image of accessed directory> 
And we can also check permissions assigned to bRoss due to being a member of Sales-Users-Group
<image of NTFS permissions>
Bob Cannot modify the file created from FILE1
<image of ctrl+s saving as>
Bob Cannot delete the file created from FILE1
<image of permission denied>



## 4. Set Quotas and file screening

### Quotas:
we want to limit the amount of storage used up by Sales-Reports to more effectively manage available storage resources, and alert us when usage gets out of hand. We will do this through file server resource manager comandlets (FSRM)

It's fairly simple to create a quota for a specific directory. We just run:

	New-FsrmQuota -Path "F:\Sales-Reports\" -Description "Limit usage to 10GB" -Size 10GB

But more interestingly, we can tell FSRM to trigger an action in case some threshold is breached.
As an example we will set up an action that will trigger at 90% storage quota capacity and will run a powershell script. Theoretically it would be ideal to send the warning to our email, but that is outside of our todays scope so we will log into a local file on the server.

This would be our example script. 

	$currentDate = Get-Date
	$message = "Sales-Reports directory storage quota reached 90% utilization"
	"$currentDate - $message" | Out-File -FilePath "C:\temp\log.txt" -Append

>We will put it at "C:\Scripts\" and name it "QuotaWarning-Sales-Reports.ps1" but both are arbitrary.

With this we set up an action

	$action = New-FsrmAction -Type Command -Command "c:\windows\system32\powershell.exe" -CommandParameters "-File C:\Scripts\QuotaWarning-Sales-Reports.ps1" -ShouldLogError

A quota threshold:

	$threshold = New-FsrmQuotaThreshold -Percentage 90 -Action $Action

And update our FSRM quota:

	Set-FsrmQuota -Path "F:\Sales-Reports" -Threshold $threshold

Now, for the sake of completeness let's verify that if we breach the threshold we get a log of it.
Suprisingly to me while trying to take up enough memory to trigger the action, i discovered that despite our virtual drive beeing 20 gigs the Sales-Reports doesn't let anyone exceed the 10 gig mark.
This is from DC1, signed in as administrator
> \<image of not beeing able to copy a file again>


### File screening

This time just to not repeat ourselves we will set a hard limit on executable files without an action. 
>The process for setting actions is the same as for quota.

	New-FsrmFileGroup -Name "Executables" -IncludePattern @("*.exe","*.bat","*.cmd","*.com","*.msi") -Active

As an example the bRoss user cannot copy over an executable to Sales-Reports
\<Image demonstrating that point>




## Plans for the next lab:
Powershell automation and scripting for common administrative tasks: User creation and group placement. resource usage mointoring and alerts.
