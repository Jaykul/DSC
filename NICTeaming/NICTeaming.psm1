Function Get-TargetReSource
{
    param
    (
    [ValidateSet("Present", "Absent")]
    [string]$Ensure = "Present",

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,
    
    [Parameter(Mandatory)]
    [ValidateSet("Switch Independent", "LACP", "Static Teaming"]
    [string]$Mode = "Switch Independent"

    [Parameter(Mandatory)]
    [ValidateSet("Dynamic", "Hyper-V Port", "IP Addresses", "Mac Addresses", "Transport Ports")]
    [string]$LBMode = "Dynamic"

    [string]$VlanID

    [Parameter(Mandatory)]
    [string]$NICs
    )
    
    $getTargetResourceResult = $null;

    #########################################Logic##############################################

    $Team = Get-NetLBFOTeam -Name $Name
    $TeamNIC = $Team | Get-NetLBFOTeamNIC | Where-Object {$_.VlanID -match $VlanID}

    If (($Team.name -match $Name) -and ($Team.Members -match $Nics) -and ($TeamNIC.VlanID -match $VlanID))  #Or Default?
    {
        $ensureResult = $true
    }
    Else
    {
        $ensureResult = $false
    }

    ########################################Results#############################################

    $getTargetResourceResult = @{
            Name    = $Team.Name
            Ensure  = $ensureResult;
            Mode    = $Team.TeamingMode
            LBMode  = $Team.LoadBalancingAlgorithm
            VlanID  = $TeamNIC.VlanID
            NICs    = $Team.Members
    }

    $getTargetResourceResult;

}

Function Set-TargetResource 
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
    [ValidateSet("Present", "Absent")]
    [string]$Ensure = "Present",

    [Parameter(Mandatory)]
    [string]$Name,

    [ValidateSet("Switch Independent", "LACP", "Static Teaming")]
    [string]$Mode = "Switch Independent"

    [ValidateSet("Dynamic", "Hyper-V Port", "IP Addresses", "Mac Addresses", "Transport Ports")]
    [string]$LBMode = "Dynamic"

    [string]$VlanID

    [Parameter(Mandatory)]
    [string]$NICs
    )
    #########################################Logic##############################################

If ($Ensure -match "Present")   {
        #Check if team exists already, if not make it
        If (!(Get-NetLBFOTeam -Name $Name -ErrorAction SilentlyContinue))   {
        #Create Teaming
            New-NetLBFOTeam -Name $Name -LoadBalancingAlgorithm $LBMode -TeamingMode $Mode -TeamMembers $NICs -TeamNicName $Name -Confirm:$False
            Sleep 5 #PS Command is too fast, resulting in missing object?!
            Set-DNSClient -InterfaceAlias $Name -RegisterThisConnectionsAddress:$True
                                                                            }
        #Setup VLANs -- If multiple VLANs are set, it will create a new virtual NIC for each one.
        If (!($VlanID)) {
        #If a VLAN isn't specified it will set it as an untagged virtual NIC.
            Get-NetLbfoTeam -Name $Name | Get-NetLbfoTeamNic | Where-Object {$_.Primary -notmatch "True"} | Remove-NetLbfoTeamNic -Confirm:$False
            Sleep 5 #PS Command is too fast, resulting in missing object?!
            Set-DNSClient -InterfaceAlias $Name -RegisterThisConnectionsAddress:$True
                        }
        Else    {
        #Remove all VLANs no longer used
        $UsedVLANs = (Get-NetLbfoTeam -Name $Name | Get-NetLbfoTeamNic | Where-Object {$_.Primary -notmatch "True"}).VlanID
        If (!($UsedVLANs))  {
            Foreach ($VLAN in $VlanID)  {
            Add-NetLBFOTeamNIC -VlanID $VLAN -Team $Name -Confirm:$False
                                        }
                            }
        Else    {
        $VLANs = Compare-Object $UsedVLANs $VlanID -IncludeEqual -ErrorAction SilentlyContinu
            Foreach ($VLAN in $VLANs)   {
                If ($VLAN.SideIndicator -match "<="){
                Get-NetLbfoTeam -Name $Name | Get-NetLbfoTeamNic | Where-Object {$_.VlanID -match $VLAN.InputObject} | Remove-NetLbfoTeamNic -Confirm:$False
                    }
                ElseIf ($VLAN.SideIndicator -match "=="){}
                ElseIf ($VLAN.SideIndicator -match "=>")    {
                Add-NetLBFOTeamNIC -VlanID $VLAN.InputObject -Team $Name -Confirm:$False
                                                            }
                                        }
                }

                }
        $UsedNetAdapters = (Get-NetLbfoTeam -Name $Name | Get-NetLbfoTeamMember).Name
        $NetAdapters = Compare-Object $UsedNetAdapters $NICs -IncludeEqual
            Foreach ($NetAdapter in $NetAdapters)   {
                If ($NetAdapter.SideIndicator -match "=="){}
                ElseIf ($NetAdapter.SideIndicator -match "<="){Get-NetLbfoTeam -Name $Name | Get-NetLbfoTeamMember | Where-Object {$_.Name -Match $NetAdapter.InputObject} | Remove-NetLbfoTeamMember -Confirm:$False}
                ElseIf ($NetAdapter.SideIndicator -match "=>"){Add-NetLbfoTeamMember $NetAdapter.InputObject -Team $Name -Confirm:$False}
                                                    }
                                }

    ########################################Results#############################################
}
