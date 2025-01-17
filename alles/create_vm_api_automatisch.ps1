$vcenter = "vcenter.netlab.fontysict.nl"
$vcentercred = Import-Clixml -Path "C:\Users\admin\Documents\vcenter_credentials.xml"
$dccred = Import-Clixml -Path "C:\Users\admin\Documents\dc_credentials.xml"
$wscred = Import-CliXml -Path "C:\Users\admin\Documents\ws_credentials.xml"

Set-PowerCLIConfiguration -Scope AllUsers -InvalidCertificateAction Warn
$datastore = "NIM01-1"
$passdc = $dccred.Password

$processedUsers = @()

while ($true) {
    $response = Invoke-RestMethod -Uri 'http://10.3.0.40:8085/Staff' -Method Get
    Write-Host "API Response: $($response | ConvertTo-Json -Depth 10)"  

    if (-not $response) {
        Write-Host 'Geen gegevens ontvangen, wacht op gegevens'
        Start-Sleep -Seconds 60
    } else {
        foreach ($user in $response.data) {  
            if ($user.voornaam -and $user.achternaam -and $user.email -and $user.afdeling) {
                $voornaam = $user.voornaam
                $achternaam = $user.achternaam
                $email = $user.email
                $afdeling = $user.afdeling

                $vmnaam = "ws-$voornaam$achternaam"
                $existingVM = Get-VM -Name $vmnaam -ErrorAction SilentlyContinue
                $existingUser = Get-ADUser -Identity "$voornaam $achternaam" -ErrorAction SilentlyContinue

                if ($existingUser -eq $null) {
                    Write-Host "Gebruiker $voornaam $achternaam bestaat niet. Ga verder met VM-check."
                } else {
                    Write-Host "Gebruiker $voornaam $achternaam bestaat al. Overslaan."
                    Start-Sleep -Seconds 30
                    continue
                }

                if ($existingVM) {
                    Write-Host "VM $vmnaam bestaat al. Overslaan."
                    Start-Sleep -Seconds 30
                    continue
                }

                Write-Host "VM en gebruiker voor $voornaam $achternaam worden aangemaakt."
                Connect-VIServer $vcenter -Credential $vcentercred
                Start-Sleep -Seconds 60

                $hostname = "ws-$voornaam$achternaam"
                $wachtwoord = "Mike123"
                $serverNaamOfIp = "test"
                $gebruikerdc = $dccred.UserName
                $domein = "mijden.lan"
                $ip = "10.2.0.32"
                $credential = New-Object System.Management.Automation.PSCredential ("admin", $wscred.Password)

                Write-host $credential.Password
                $vm = New-VM -name $vmnaam -Template ws-user-temp -ResourcePool I540703 -Datastore NIM01-1 -Location I540703
                Write-host $vmnaam
                Start-Sleep -Seconds 60
                Start-VM -VM $vmnaam
                Start-Sleep -Seconds 60

                $vmTeZoeken = "ws-$voornaam$achternaam"
                $vm = Get-VM -Name $vmTeZoeken
                $ipv4Adres = $vm.Guest.IPAddress | Select-Object -First 1
                Write-Output $ipv4Adres
                Start-Sleep -Seconds 90
                Disconnect-VIServer -Server "vcenter.netlab.fontysict.nl" -Confirm:$false

                Invoke-Command -ComputerName $ipv4Adres -Credential $credential -ScriptBlock {
                    if ($using:afdeling -eq "Hr") {
                        winget install Google.Chrome --accept-package-agreements --accept-source-agreements --silent
                        Start-Sleep -seconds 30
                        Rename-Computer -NewName $using:hostname -Force -Restart
                    } else {
                        winget search Discord
                        winget install Discord -s msstore --accept-package-agreements --accept-source-agreements --silent
                        Start-Sleep -seconds 30
                        Rename-Computer -NewName $using:hostname -Force -Restart
                    }
                }

                do {
                    Start-Sleep -Seconds 240
                    $pingResult = Test-Connection -ComputerName $ipv4Adres -Count 1 -Quiet
                } until ($pingResult)

                Start-Sleep -Seconds 120

                $domeinToevoegen = Invoke-Command -ComputerName $ipv4Adres -Credential $credential -ScriptBlock {
                    try {
                        Add-Computer -DomainName $using:domein -Credential $using:dccred -Force -Restart
                        return $true
                    } catch {
                        Write-Host "Fout bij het toevoegen aan het domein: $_"
                        return $false
                    }
                }

                if (-not $domeinToevoegen) {
                    Write-Host "Domein join mislukt. Probeer opnieuw."
                    Start-Sleep -Seconds 30
                }

                Write-Host "Eerste gebruiker succesvol verwerkt."
                $processedUsers += "$voornaam $achternaam" 
            } else {
                Write-Host 'Geen gegevens ontvangen, wacht op gegevens'
                Start-Sleep -Seconds 30
            }
        }
    }
}
