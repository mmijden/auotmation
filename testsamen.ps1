# Define global array to store user records
$global:userRecords = @()

# Script 1: Fetch and process user data from REST API
$dccred = Import-Clixml -Path "C:\Users\admin\Documents\dc_credentials.xml"
$dccred = New-Object System.Management.Automation.PSCredential ($dccred.UserName, $dccred.Password)
Invoke-Command -ComputerName 10.3.0.2 -Credential $dccred -ScriptBlock {
    while ($true) {
        try {
            $Response = Invoke-RestMethod http://10.3.0.40:8085/Staff
            Write-Host $Response 
            
            foreach ($user in $Response.data) {
                $voornaam = $user.Voornaam
                $achternaam = $user.Achternaam
                $personeelsnummer = $user.Personeelsnummer
                $afdeling = $user.Afdeling
                $email = $user.Email

                $samAccountName = "$voornaam $achternaam"
                $wachtwoord = [System.Web.Security.Membership]::GeneratePassword(8,2)
                $controlegebruiker = Get-ADUser -Filter {SamAccountName -eq $samAccountName}
                if ($controlegebruiker -eq $null) {
                    New-ADUser -Name $voornaam -GivenName $voornaam -Surname $achternaam -SamAccountName $samAccountName -Department $afdeling -UserPrincipalName "$samAccountName@mijden.lan" -Path "OU=$afdeling,DC=mijden,DC=lan" -AccountPassword (ConvertTo-SecureString $wachtwoord -AsPlainText -Force) -Enabled $true -ChangePasswordAtLogon $true
                    $object = [PSCustomObject]@{
                        Voornaam = $voornaam
                        Achternaam = $achternaam
                        Afdeling = $afdeling
                        Email = $email
                        SamAccountName = $samAccountName
                        Wachtwoord = $wachtwoord
                    }
                    $global:userRecords += $object
                    
                    $emailontvanger = $email
                    $emailafzender = "mike.fhict@gmail.com"
                    $onderwerp = "Uw nieuwe account"
                    $body = @"
Beste $voornaam,
Uw account is aangemaakt.
Uw gebruikersnaam is: $samAccountName 
Uw wachtwoord is: $wachtwoord
Met vriendelijke groet,
IT-afdeling vd M
"@
                    $smtpServer = "smtp.gmail.com"
                    $port= 587
                    $userName = 'mike.fhict@gmail.com'
                    $password = "lyzd gjuh otjy szdg"
                    [SecureString]$securepassword = $password | ConvertTo-SecureString -AsPlainText -Force
                    $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $securepassword

                    Send-MailMessage -To $emailontvanger -From $emailafzender -Subject $onderwerp -Body $body -SmtpServer $smtpServer -Port $port -UseSsl -Credential $credential
                    Write-Host "Gebruiker $samAccountName aangemaakt met wachtwoord: $wachtwoord er is een email verstuurd naar het opgegeven mail adress"
                    
                    # After creating the user, create the VM
                    $vcenter = "vcenter.netlab.fontysict.nl"
                    $vcentercred = Import-Clixml -Path "C:\Users\admin\Documents\vcenter_credentials.xml"
                    Set-PowerCLIConfiguration -Scope AllUsers -InvalidCertificateAction Warn
                    $datastore = "NIM01-1"
                    
                    Connect-VIServer $vcenter -Credential $vcentercred
                    Start-Sleep -Seconds 60

                    $vmnaam = "ws-$voornaam$achternaam"
                    $hostname = "ws-$voornaam$achternaam"
                    $serverNaamOfIp = "test"
                    $gebruikerdc = $dccred.UserName
                    $domein = "mijden.lan"
                    $ip = "10.2.0.32"
                    $credential = New-Object System.Management.Automation.PSCredential ("admin", $wscred.Password)

                    Write-host $credential.Password
                    $vm = New-VM -name $vmnaam -Template ws-user-temp -ResourcePool I540703 -Datastore NIM01-1 -Location I540703  

                    Write-Host "VM $vmnaam aangemaakt"

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
                        continue  # Ga door met de volgende iteratie van de while-lus
                    }

                    Write-Host "Eerste gebruiker succesvol verwerkt en verwijderd uit de array."
                } else {
                    Write-Host "Gebruiker $samAccountName bestaat al."
                }
            }
        } catch {
            Write-Host "Er is een fout opgetreden bij het verwerken van de gebruikers: $_"
        }
        Start-Sleep -Seconds 30
    }
}
