
<#PSScriptInfo

.VERSION 1.0.0

.GUID 070a19ef-403b-4c93-b317-b3ffabeb46f5

.AUTHOR Jason Byway

.COMPANYNAME Microsoft

.COPYRIGHT 

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES Microsoft.RDInfra.RDPowershell

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>

<# 

.DESCRIPTION 
Connect to Windows Virtual Desktop Service, list all Desktop Application Groups and then allow admin to 
update CustomRDPProperties for the host pool. This will require the use of the linked json file. 

To Run this script;

1. Update your json file, save to a path you can access locally. 
    - When updating the json file you will only need to update the "ConfiguredValue", options are provided in the description 
    field and typically are a number choice. You need to retain the "" (eg: "2").
    - To restore to default either set the value to the provided default value or return to empty string ("")
2. Run the script and pass the path (relative or absolute) of the json file. Once validated the custom RDP settings
    string will be built and upon selecting your Host Pool and confirming the update your host pool will be updated. 

21/8/2019 - Current design requires you to update all host pool settings vs being able to select individual settings to update,
    retain your json file to ensure consistency between sessions (duplicate the json if you like as file name is not fixed in script)


#> 




function set-wvdcustomrdpsettings() {
    Param(
            [Parameter(Mandatory = $false, ValueFromPipeline=$false, HelpMessage ="Enter your Tenant Name")]
            [ValidateNotNullorEmpty()]
            [string] $TenantName,
 
            [Parameter(Mandatory = $false, ValueFromPipeline=$false, HelpMessage ="Enter your Host Pool")]
            [ValidateNotNullorEmpty()]
            [string] $HostPool,

            [Parameter(Mandatory = $false, ValueFromPipeline=$false, HelpMessage ="Enter your App Group Name")]
            [ValidateNotNullorEmpty()]
            [string] $AppGroupName,
                        
            [Parameter(Mandatory = $false, ValueFromPipeline=$false)]
            [string] $DeploymentURL = "https://rdbroker.wvd.microsoft.com", #default WVD Broker Service

            [Parameter(Mandatory = $true, ValueFromPipeline=$false, HelpMessage ="Enter a valid path to the json file")]
            [ValidateNotNullorEmpty()]
            [ValidateScript({if(!($_ | Test-Path)){
                                throw "File or folder does not exist"}
                            if(!($_ | Test-Path -PathType Leaf)){
                                throw "The path parameter must be a file. Folder paths are not allowed"}
                            if(!($_ -match "(\.json)")){
                                throw "You must enter a valid .json file"}
                            if(!(ConvertFrom-Json -InputObject (gc $_ -raw))){
                                throw "Not Valid json format"}
                            return $true})]
            [string] $configfile
            )
           
          
           

            # Jump to function to build the command string for the configured values on the supporting json
            $commandstring = new-customrdpsettings $configfile

            # Successfully obtained command string
            Write-host "[SUCCESS] Returned customrdppropertystring $commandstring." -ForegroundColor Green
                
            # Connect to WVD tenant as required
    Try 
        {
            #Check if user is already connected to WVD Service and catch error if not
            Write-Host "Initiate WVD Service Connection" -ForegroundColor Gray
            Write-Host "Please wait - checking for connection to WVD Service" -ForegroundColor Gray
            $RDSContext = Get-RdsContext -ErrorAction Stop
            Write-Host "WVD Context Found - Continuing" -ForegroundColor Gray

        }
    
    Catch  
        
        {
            #Connect to WVD Service as user is not already connected
            Write-Warning "You are not currently connected to the WVD Service - attempting to login...."
    
            
            #Connect to WVD Service
            Add-RdsAccount -DeploymentUrl $DeploymentURL | out-host
            Write-host "[SUCCESS] Logged into your WVD Service" -ForegroundColor Green | out-host
        
        }

    # Check if Host Pool Information has been passed through and if not then enumerate RemoteApp Resource Types they have permission to access
    If(!$TenantName -or !$HostPool -or !$AppGroupName)
        {
          $apppools = @()
          $tenant = Get-RdsTenant
          Write-Host "Obtaining list of Desktop Application Groups across your tenants. Please wait." -ForegroundColor Gray | out-host
          Foreach ($i in $tenant)
            {
                $hosts = Get-RdsHostPool -TenantName $i.TenantName
                    
                Foreach ($j in $hosts)
                    {
                        $apppools += Get-RdsAppGroup -TenantName $j.Tenantname -HostPoolName $j.HostPoolName 
 
                    }
       
            }
          $apppools = $apppools | Where-Object {$_.ResourceType -like 'Desktop'} | Out-GridView -Title "Please choose your AppGroup..." -OutputMode Single 
          $apppools
          
          If(!$apppools)
            {
              NoSelectionHandling  
            }
          Else 
            {
                #Define parameter variables to continue script
                $TenantName = $apppools.TenantName
                $AppGroupName = $apppools.AppGroupName
                $HostPool = $apppools.HostPoolName
                Write-Host "$AppGroupName on $HostPool selected. Obtaining list of current options - please wait." -ForegroundColor Gray
                $hostpooloptions = Get-RdsHostPool -TenantName $apppools.TenantName -Name $apppools.HostPoolName
                $hostpooloptions #| out-for

                
            }
        }
        
        #Jump to function to configure custom rdp properties on to the selected host pool
        set-rdshostpoolsettings $commandstring $hostpooloptions



}

function new-customrdpsettings {
            Param($configfile)
            try {
                    #Convert the json into an object array
                  #  Write-Host "Validating your settings file" -ForegroundColor Gray
               
                    $json = ConvertFrom-Json -InputObject (gc $configfile -Raw) -ErrorAction Stop
                     # Not required but display first value of array from json ('Return first value of JSON file ' + $json[0])
                }
            catch
                {
                    Write-Host "Conversion Failed" -ForegroundColor Red
                    Write-Host $_.ErrorMessage -ForegroundColor Red
                }

              
                $customoptions = $json.where{-not $_.ConfiguredValue -eq ''}
                
               # Write-Host "CustomOptions = " + $customoptions -ForegroundColor Gray

  
               
                [string] $commandString= $null
     
              foreach ($j in $customoptions)
                {  
                #($newsettings += ($j.RDPSetting + $j.ConfiguredValue))

                # Don't add first value if null
                if ("" -eq $commandString) 
                    {
                        $commandString = $($j.RDPSetting + $j.ConfiguredValue)
                }
                # Build out the command string with all configured options and separate with a ;
                else {
                        $commandString = $commandString +";"+$($j.RDPSetting + $j.ConfiguredValue)
                    }
                
                }

                # Output the commandstring
                         return $commandString

            
                
     }


function NoSelectionHandling {
            Write-Host -NoNewline "You have not made a selection. Would you like to try restart? (Y/N): " -ForegroundColor Red
            $Response = Read-Host
        
                If ($Response -ne "Y")
                    {
                        Write-Host "Exiting. Goodbye."
                        Break
                    }
                
                # Restart function with existing parameters if user chooses to try again
                Else {
                        wvd-publishapps #-TenantName $TenantName -HostPool $HostPool -AppGroupName $AppGroupName
                     }

}

function set-rdshostpoolsettings{
    Param (
            $commandstring,
            $hostpooloptions)
        
        # Replace the host pool custom rdp properties values - begin by building the query
        Write-Debug "[FUNCTION] set-rdshostpoolsettings"
        Write-Debug "[BEGIN] begin creating the command. This will overwrite the existing customRDPProperties"


        Try{
            $TenantName = $hostpooloptions.TenantName
            $HostPoolName = $hostpooloptions.HostPoolName
            $PSHostPoolCmdString = ,("Set-RdsHostPool -TenantName $TenantName -Name $HostPoolName -CustomRdpProperty ""$commandstring""")

            Write-Host "You are about to apply the following update to the host pool $HostpoolName." -ForegroundColor Yellow
            Write-Host $PSHostPoolCmdString -ForegroundColor Yellow
            Write-Host -NoNewline "Would you like to proceed? (Y/N): " -ForegroundColor Yellow
            $response = Read-Host

                If ($response -ne "Y")
                    {
                        Write-Host "You have chosen to not continue. Exiting Script. Goodbye."
                        Break
                    }
                
                Else {
                        Write-Host "Updating host pool, please wait..." -ForegroundColor Gray
                        
                        Set-RdsHostPool -TenantName $TenantName -HostPoolName $HostPoolName -CustomRdpProperty ""

                        # Execute the command
                        Set-RdsHostPool -TenantName $TenantName -Name $HostPoolName -CustomRdpProperty "$commandstring"

                        Write-Host "[SUCCESS] The host pool has been successfully updated. Settings will apply on the user's next update. Goodbye." -ForegroundColor Green
                        Break
                    }
        }
        Catch {
           
            Write-Host "Failed to apply the updated RDP Profile to the host pool $HostPoolName" -ForegroundColor Red
            Write-Host $_.ErrorMessage     
        }
        
}

# set-wvdcustomrdpsettings -configfile .\CustomRDPPropertyValues.json

