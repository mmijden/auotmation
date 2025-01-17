param(
    [Parameter(Mandatory=$true)]
    [string]$Voornaam,
    
    [Parameter(Mandatory=$true)]
    [string]$Achternaam
)

# Import required credentials
$vcenter = "vcenter.netlab.fontysict.nl"
$vcentercred = Import-Clixml -Path "C:\Users\admin\Documents\vcenter_credentials.xml"
$dccred = Import-Clixml -Path "C:\Users\admin\Documents\dc_credentials.xml"
$wscred = Import-CliXml -Path "C:\Users\admin\Documents\ws_credentials.xml"

# Configure PowerCLI
Set-PowerCLIConfiguration -Scope AllUsers -InvalidCertificateAction Warn

# Function to update status via API
function Update-OffboardingStatus {
    param(
        [string]$Voornaam,
        [string]$Achternaam,
        [string]$Status
    )
    
    $uri = "http://localhost:8085/offboard/status/$Voornaam/$Achternaam"
    $body = @{
        status = $Status
    } | ConvertTo-Json
    
    try {
        Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json"
    }
    catch {
        Write-Host "Failed to update status: $_"
    }
}

try {
    Write-Host "Start offboarding proces..."
    $samAccountName = "$Voornaam $Achternaam"
    $vmnaam = "ws-$Voornaam-$Achternaam"

    Update-OffboardingStatus -Voornaam $Voornaam -Achternaam $Achternaam -Status "Connecting to vCenter"

    # Connect to vCenter
    Write-Host "Verbinding maken met vCenter..."
    Connect-VIServer $vcenter -Credential $vcentercred

    # Get and remove VM
    $vm = Get-VM -Name $vmnaam -ErrorAction SilentlyContinue
    if ($vm) {
        if ($vm.PowerState -eq "PoweredOn") {
            Update-OffboardingStatus -Voornaam $Voornaam -Achternaam $Achternaam -Status "Powering off VM"
            Write-Host "VM $vmnaam wordt uitgeschakeld..."
            Stop-VM -VM $vm -Confirm:$false
            Start-Sleep -Seconds 30
        }
        Update-OffboardingStatus -Voornaam $Voornaam -Achternaam $Achternaam -Status "Removing VM"
        Write-Host "Verwijderen van VM $vmnaam..."
        Remove-VM -VM $vm -DeletePermanently -Confirm:$false
        Update-OffboardingStatus -Voornaam $Voornaam -Achternaam $Achternaam -Status "VM Removed"
        Write-Host "✓ VM succesvol verwijderd"
    } else {
        Update-OffboardingStatus -Voornaam $Voornaam -Achternaam $Achternaam -Status "VM not found"
        Write-Host "! VM niet gevonden"
    }

    # Disconnect from vCenter
    Disconnect-VIServer -Server $vcenter -Confirm:$false

    # Remove AD user
    Update-OffboardingStatus -Voornaam $Voornaam -Achternaam $Achternaam -Status "Removing AD account"
    $adUser = Get-ADUser -Filter {SamAccountName -eq $samAccountName} -ErrorAction SilentlyContinue
    if ($adUser) {
        Write-Host "Verwijderen van AD account..."
        Remove-ADUser -Identity $adUser -Confirm:$false
        Update-OffboardingStatus -Voornaam $Voornaam -Achternaam $Achternaam -Status "AD account removed"
        Write-Host "✓ AD account succesvol verwijderd"
    } else {
        Update-OffboardingStatus -Voornaam $Voornaam -Achternaam $Achternaam -Status "AD account not found"
        Write-Host "! AD account niet gevonden"
    }

    Update-OffboardingStatus -Voornaam $Voornaam -Achternaam $Achternaam -Status "Completed"
    Write-Host "Offboarding voltooid!"
}
catch {
    Update-OffboardingStatus -Voornaam $Voornaam -Achternaam $Achternaam -Status "Error: $_"
    Write-Host "Error: $_"
    exit 1
}
