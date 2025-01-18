$vcenter = "vcenter.netlab.fontysict.nl"
$vcentercred = Import-Clixml -Path "C:\Users\admin\Documents\vcenter_credentials.xml"
$dccred = Import-Clixml -Path "C:\Users\admin\Documents\dc_credentials.xml"
$wscred = Import-CliXml -Path "C:\Users\admin\Documents\ws_credentials.xml"
$wscred | Format-List

Set-PowerCLIConfiguration -Scope AllUsers -InvalidCertificateAction Warn
$datastore = "NIM01-1"
$passdc = $dccred.Password

$processedUsers = @()

while ($true) {
    # API-aanroep om gegevens op te halen
    $response = Invoke-RestMethod -Uri 'http://10.3.0.40:8085/Staff' -Method Get

    # Verwerk de API-respons
    if (-not $response) {
        Write-Host 'Geen gegevens ontvangen, wacht op gegevens'
        Start-Sleep -Seconds 60
        continue
    }

        $data = $response

        if (-not $data) {
            Write-Host 'Geen gegevens ontvangen, wacht op gegevens'
            Start-Sleep -Seconds 60
            continue
        }

            foreach ($user in $data) {
                $voornaam = $user.voornaam
                $achternaam = $user.achternaam
                $hostname = $user.hostname

                if (-not ($processedUsers -contains "$voornaam $achternaam")) {
                    Write-Host "Eerste gebruiker: Voornaam: $voornaam, Achternaam: $achternaam"

                    Connect-VIServer $vcenter -Credential $vcentercred
                    Start-Sleep -Seconds 60

                    $vmnaam = "ws-$voornaam$achternaam"
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
                        if ($using:user.afdeling -eq "Hr") {  
                            winget install Google.Chrome --accept-package-agreements --accept-source-agreements --silent
                            start-sleep -seconds 30
                            Rename-Computer -NewName $using:hostname -Force -Restart
                        } else {
                            winget search Discord
                            winget install Discord -s msstore --accept-package-agreements --accept-source-agreements --silent
                            start-sleep -seconds 30
                            Rename-Computer -NewName $using:hostname -Force -Restart
                        }
                    }

                    do {
                        Start-Sleep -Seconds 240
                        $pingResult = Test-Connection -ComputerName $ipv4Adres -Count 1 -Quiet
                    } until ($pingResult)

                    Start-Sleep -Seconds 120  # Wacht nu 120 seconden voordat je de computer aan het domein toevoegt

                    # Probeer de computer aan het domein toe te voegen met foutafhandeling
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
                }
            }
        }
    }
    Start-Sleep -Seconds 60  # Wacht voordat je de volgende API-aanroep doet
}
