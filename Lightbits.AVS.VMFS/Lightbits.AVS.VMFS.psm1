
Set-Variable -Name "AdminQueueSize"   -Value 32    -Option constant -Description "NVMe/TCP AdminQueueSize"
Set-Variable -Name "ControllerId"     -Value 65535  -Option constant -Description "NVMe/TCP ControllerId"
Set-Variable -Name "IoQueueNumber"    -Value 8      -Option constant -Description "NVMe/TCP IO Queue Number"
Set-Variable -Name "IoQueueSize"      -Value 256    -Option constant -Description "NVMe/TCP IO Queue Size"
Set-Variable -Name "KeepAliveTimeout" -Value 256    -Option constant -Description "NVMe/TCP KeepAliveTimeout"
Set-Variable -Name "PortNumber"       -Value 4420    -Option constant -Description "NVMe/TCP Target Port Number"


<#
    .SYNOPSIS
     This function connects an esxi host to the specified storage cluster node/target.

     1. ESXi host IP address or DNS
     2. ESXi NVMe/TCP Storage adaper name 
     3. Storage Node EndPoint IP address
     4. Storage SystemNQN
     
    .PARAMETER hostAddress
     ESXi host IP Address 

    .PARAMETER hostAdapter
     ESXi host storage adapter name 

    .PARAMETER nodeAddress
     Storage Node Address

    .PARAMETER storageSystemNQN
     Storage system NQN


    .EXAMPLE
     Connect-LightbitsTarget -hostAddress "192.168.0.1" -hostAdapter "adapter-name" -nodeAddress "192.168.0.1" -storageSystemNQN "nqn.2016-01.com.lightbitslabs:uuid:46edb489-ba18-4dd4-a157-1d8eb8c32e21"

    .INPUTS
     ESXi Address, Storage Adapter, Storage Node Address, Storage systemNQN

    .OUTPUTS
     None.
#>
function Connect-LightbitsTarget {
 Param
     (
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'ESXi host network address')]
        [string] $hostAddress,

        [Parameter(
            Mandatory = $true,
            HelpMessage = 'NVMe/TCP Storage Adapter Name')]
        [string] $hostAdapter,

        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Target storage Node datapath address')]
        [string]     $nodeAddress,


        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Target storage SystemNQN')]
        [string]     $storageSystemNQN

     )
        
   Write-Host "Connecting to targets via Storage Adapter on given ESXi host " $hostAddress;
   Write-Host " " ;

   $HostEsxcli = $null;
  
   try {
      $HostEsxcli = Get-EsxCli -VMHost $hostAddress 
       }
   catch {
     throw " Failed to execute Get-EsxCli cmdlet on host $($hostAddress). Make sure valid ESXi IP/DNS is provided."
   }

  if ($HostEsxcli) { 
      Write-Host "Connected to host via powercli-esxcli"
      
      try {
    
        $EsxCliResult = $HostEsxcli.nvme.fabrics.connect(
        $hostAdapter, $AdminQueueSize, $ControllerId, 
        $null, $IoQueueNumber, $IoQueueSize, $nodeAddress.Trim(),
        $KeepAliveTimeout, $PortNumber, $storageSystemNQN, $null, $null 
        );
        
        if ($EsxCliResult){
            Write-Host "ESXi host is connected to storage controller " $hostAddress 
        }
       else {
        throw
       }
      }
      catch {
        throw "Failed to connect ESXi NVMe/TCP storage adapter to storage controller  $($item) " 
      }  
     Write-Host "Connecting Controller status: "$EsxCliResult;
    }

     Get-VMHostStorage -VMHost $hostAddress -RescanAllHba

 }



<#
    .SYNOPSIS
     This function disconnects an esxi host from the specified storage cluster node/target.

     1. ESXi host IP address or DNS
     2. ESXi NVMe/TCP Storage adaper name 
     3. Storage SystemNQN
     
    .PARAMETER hostAddress
     ESXi host IP Address 

    .PARAMETER hostAdapter
     ESXi host storage adapter name

    .PARAMETER storageSystemNQN
     Storage system NQN

    .EXAMPLE
     Connect-LightbitsTarget -hostAddress "192.168.0.1" -hostAdapter "adapter-name"  -storageSystemNQN "nqn.2016-01.com.lightbitslabs:uuid:46edb489-ba18-4dd4-a157-1d8eb8c32e21"

    .INPUTS
     ESXi Address, Storage Adapter, Storage systemNQN

    .OUTPUTS
     None.
#>

function Disconnect-LightbitsTarget {
    Param
     (
        [Parameter(
            Mandatory = $true,
            HelpMessage = 'ESXi host network address')]
        [string] $hostAddress,

        [Parameter(
            Mandatory = $true,
            HelpMessage = 'NVMe/TCP Storage Adapter Name')]
        [string] $hostAdapter,

        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Target storage SystemNQN')]
        [string]     $storageSystemNQN

     )

     Write-Host "Disconnecting controllers from targets on given ESXi host " $hostAddress;
     Write-Host " " ;
     
     $hostEsxcli = $null;

     try {

         $hostEsxcli = Get-EsxCli -VMHost $hostAddress ;
         Write-Host " EsxCli connected to host $($hostAddress)"
         if (!$hostEsxcli) {
             throw;
         }
       }
     catch {
        throw " Failed to execute Get-EsxCli cmdlet on host $($hostAddress). Make sure valid ESXi IP/DNS is provided."
     }

     try {

          $Controllers = $hostEsxcli.nvme.controller.list();

          if ($Controllers -and $Controllers.Count -ge 0) {

           foreach ($item in $Controllers) {
              $result = $hostEsxcli.nvme.fabrics.disconnect($item.Adapter, $item.ControllerNumber, $storageSystemNQN);
              Write-Host "Diconnecting Controller status: "$result;
            }
        
            Get-VMHostStorage -VMHost $hostAddress -RescanAllHba 

          }
        
          else {
            Write-Host "No NVMe/TCP controller found on given host " $hostAddress    
          } 
    }
     catch {
        <#Do this if a terminating exception happens#>
    } 
    Write-Host ""
}



<#
    .SYNOPSIS
     This function creates VMFS datastore on given ESXi host using NVMe/TCP transport.

     1. vCenter IP address or DNS
     2. ESXi IP address or DNS
     3. New Datastore Name
     4. Device Path on ESXi host
     
    .PARAMETER vCenterAddress
     vCenter IP Address 

    .PARAMETER hostAddress
     ESXi host IP Address 

    .PARAMETER datastoreName
     New Datastore Name

    .PARAMETER devicePath
     Device Path on ESXi host

    .EXAMPLE
     Create-NVMeDatastore -vCenterAddress "192.168.0.1" -hostAddress "192.168.0.10"  -datastoreName "data-name01" -devicePath "eui.58204375a0b5408285a89390e1510fec"

    .INPUTS
     vCenter address, ESXi host address, New storage name, available NVMe device path 

    .OUTPUTS
     None.
#>

function New-NVMeDatastore {
    Param
     (
  
       [Parameter(
         Mandatory = $true,
         HelpMessage = 'vCenter network address')]
       [string] $vCenterAddress,

        [Parameter(
            Mandatory = $true,
            HelpMessage = 'ESXi host network address')]
        [string] $hostAddress,

        [Parameter(
            Mandatory = $true,
            HelpMessage = 'New datastore name')]
        [string] $datastoreName,

        [Parameter(
            Mandatory = $true,
            HelpMessage = 'NVMe device path')]
        [string]     $devicePath

     )

     Write-Host "Creating new datastore $($datastoreName) on vCenter Server "  $vCenterAddress 
     
     $AvailableDatastore = $null
     
     try {
             Write-Host " creating datastore now ... ;;;---;"
             $AvailableDatastore = Get-Datastore -Name $datastoreName
             Write " creating datastore now ... ;;;;"
             if ($AvailableDatastore){
                Write-Host "Datastore with given name alreay exist, use different name for new datastore"
                Exit 

             } 

     }
     catch {
        throw " Failed to execute Get-Datastore cmdlet on host $($vCenterAddress)."
     }

     try {
        
          Write-Host " creating datastore now ... "
          $result = New-Datastore -Vmfs -FileSystemVersion 6 -VMHost $hostAddress -Name $datastoreName -Path $devicePath
          Write-Host $result
          
          Get-VMHostStorage -VMHost $hostAddress -RescanAllHba -RescanVmfs
          $AvailableDatastore = Get-Datastore -Name $datastoreName

          if ($AvailableDatastore){
            Write-Host " New datastore created successfully"
          }

     }
     catch {
        throw " Failed to create  new datastore on host $($hostAddress)."
     }
  
     Write-Host " " ;
     
}