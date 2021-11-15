# Download and extract to script folder: https://github.com/ipinfo/cli/releases/download/ipinfo-2.2.0/ipinfo_2.2.0_windows_amd64.zip
# Download and extract psping.exe to script folder: https://download.sysinternals.com/files/PSTools.zip 

$avdgwip = @()
$msrdcpid = @()
$tracertarray = @()

function get-avdprocesses {
    [cmdletbinding()]
    Param()

    $avdgwip = @()
    # Get Process ID of MSRDC and IP address of the AVD Gateway in use by any sessions
    Write-Verbose "[Discovering current MSRD Process ID]"
    $msrdcpid = (Get-Process -Name msrdc).id
    Write-Verbose "[Process ID of MSRDC]"
    $msrdcpid | ForEach-Object {Write-Verbose "$_ `r`n"}

    Write-Verbose "[Discovering currently established AVD Gateway IP(s)]"
    $avdgwip = (Get-NetTCPConnection -OwningProcess $msrdcpid -state Established).RemoteAddress | select-object -Unique
    Write-Verbose "[Remote AVD Gateway IP(s) Connected]"
    $avdgwip | Foreach-Object {Write-Verbose "$_ `r"}
    
    Write-Verbose "[Ending get-avdprocesses function and returning values]"
    return $avdgwip, $msrdcpid

}

$avdgwip, $msrdcpid = get-avdprocesses





# Gather details of resolved AVD Gateway - this may not be the one you are using


#write-output ("Resolved GW Region URL: " + ($avdgwapi.content | ConvertFrom-Json | Select-Object -ExpandProperty 'RegionUrl'))
#write-output ("Resolved GW Cluster URL: " + ($avdgwapi.content | ConvertFrom-Json | Select-Object -ExpandProperty 'ClusterUrl'))
#write-output ""


function get-avdgatewayinfo {
    [CmdletBinding()]Param()

    
    # Get AVD Gateway IP address and location details
    $avdgwip = $avdgwapi.content | ConvertFrom-Json | Select-Object -ExpandProperty 'GatewayIp'
    $avdgwregion = $avdgwapi.content | ConvertFrom-Json | Select-Object -ExpandProperty 'RegionUrl'
    $avdgwcluster = $avdgwapi.content | ConvertFrom-Json | Select-Object -ExpandProperty 'ClusterUrl'
    $avdgwregion = $avdgwregion.Substring(0, $avdgwregion.Length - 1)
    $avdgwcluster = $avdgwcluster.Substring(0, $avdgwcluster.Length - 1)
    Write-Verbose "#### AVD Gateway Details ####"
    Write-Verbose "AVD Gateway IP: $avdgwip"
    Write-Verbose "AVD Gateway Region: $avdgwregion"
    Write-Verbose "AVD Gateway Cluster: $avdgwcluster"
    Write-Verbose ""

}
#Create empty array for tracert

function get-hopstogateway {
    param(
        [cmdletbinding()]
        [Parameter(Mandatory=$true)]
        [string]$avdgwip
    )
    
# Obtain latency of MSRDC connection to remote AVD gateway for any open session
#foreach ($gwip in $remoteavdgwip) {
    
    Write-Verbose "[Begin PSPing to AVD Gateway IP: $avdgwip]`r`n"
    
    if ($VerbosePreference -eq 'SilentlyContinue'){
    $latency = .\psping.exe -q ($avdgwip + ":443")}
    else{
    Write-Verbose $latency = .\psping.exe ($avdgwip + ":443")
    }
    $pspingstats = ($latency[-2] -split ',').trim()
    $pspinglatency = ($latency[-1] -split ',').trim()
    
    # Obtain the Gateway Region for this particular AVD Gateway IP
    $web = Invoke-WebRequest -Uri https://$avdgwip/api/health -Headers @{Host = "rdgateway.wvd.microsoft.com" }
    write-Output "Remote Gateway IP: $avdgwip"
    $gwurl = $web.Content | ConvertFrom-Json | select-object -expandproperty 'RegionUrl'
    Write-Output "Gateway URL: $gwurl"
    
    write-output "PSPing Attempts : $pspingstats"
    write-output "PSPing Latency : $pspinglatency"
    Write-Output ""

    # Trace route to the AVD Gateway up to 20 hops
    Write-Output "Gathering Traceroute information. This will take a minute"
    $tracert = TRACERT.EXE -h 20 -w 1500 $avdgwip
    Write-Output $tracert
    $regex = ‘\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b’
    $tracertips = $tracert | select-string -Pattern $regex -AllMatches | % { $_.Matches } | % { $_.Value } # Get all IP addresses from traceroute output
    $tracertarray += $tracertips

#}

}



# Create array of unique IPs of client and tracert and write to file
$userIP = $clientIP.Content | ConvertFrom-Json | select-object -expandproperty 'ip'
$map = @($remoteavdgwip, $userIP, $tracertarray)
set-content .\ips.txt $map

# Use ipinfo to get location details of client and display on map
.\ipinfo.exe map .\ips.txt


# Possible improvements:https://jrich523.wordpress.com/2011/04/15/netstat-for-powershell/




# Gather local IP of client and location details
$clientIP = Invoke-WebRequest -Uri http://ipinfo.io/json
Write-Output "Client Public IP Details"
write-output $clientIP.content
Write-Output ""


# Get AVD Gateway IP Address
Write-Verbose "Regional URL of resolved AVD Gateway"
$avdgwapidetails = Invoke-WebRequest -Uri https://rdgateway.wvd.microsoft.com/api/health
($avdgwapidetails.Content) | ConvertFrom-Json | Select-Object -ExpandProperty 'RegionUrl' | Write-Verbose -Verbose
