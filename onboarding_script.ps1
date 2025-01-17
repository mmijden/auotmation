# Define credentials and vCenter information
$dccred = Import-Clixml -Path "C:\Users\admin\Documents\dc_credentials.xml"
$vcentercred = Import-Clixml -Path "C:\Users\admin\Documents\vcenter_credentials.xml"
$wscred = Import-Clixml -Path "C:\Users\admin\Documents\ws_credentials.xml"
$vcenter = "vcenter.netlab.fontysict.nl"

Invoke-Command -ComputerName 10.3.0.2 -Credential $dccred -ScriptBlock {
    while ($true) {
        $Response = Invoke-RestMethod http://10.3.0.40:8085/Staff
        Write-Host $Response 
        
        foreach ($user in $response.data) {
            $voornaam = $user.Voornaam
            $achternaam = $user.Achternaam
            $afdeling = $user.Afdeling
            $email = $user.Email
            
            $samAccountName = "$voornaam $achternaam"
            $wachtwoord = [System.Web.Security.Membership]::GeneratePassword(8,2)
            $controlegebruiker = Get-ADUser -Filter {SamAccountName -eq $samAccountName}
            if ($controlegebruiker -eq $null) {
                New-ADUser -Name $voornaam -GivenName $voornaam -Surname $achternaam -SamAccountName $samAccountName -Department $afdeling -UserPrincipalName "$samAccountName@mijden.lan" -Path "OU=$afdeling,DC=mijden,DC=lan" -AccountPassword (ConvertTo-SecureString $wachtwoord -AsPlainText -Force) -Enabled $true -ChangePasswordAtLogon $true
                
                $emailontvanger = $email
                $emailafzender = "mike.fhict@gmail.com"
                $onderwerp = "Uw nieuwe account"
                $body = "Beste $voornaam, Uw account is aangemaakt. Uw gebruikersnaam is: $samAccountName. Uw wachtwoord is: $wachtwoord."
                $smtpServer = "smtp.gmail.com"
                $port= 587
                $userName = 'mike.fhict@gmail.com'
                $password = "lyzd gjuh otjy szdg"
                [SecureString]$securepassword = $password | ConvertTo-SecureString -AsPlainText -Force
                $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $userName, $securepassword
                
                Send-MailMessage -To $emailontvanger -From $emailafzender -Subject $onderwerp -Body $body -SmtpServer $smtpServer -Port $port -UseSsl -Credential $credential
                Write-Host "Gebruiker $samAccountName aangemaakt met wachtwoord: $wachtwoord. Er is een email verstuurd naar het opgegeven mailadres."

                Connect-VIServer $vcenter -Credential $vcentercred
                Start-Sleep -Seconds 60

                $vmnaam = "ws-$voornaam$achternaam"
                $hostname = "ws-$voornaam$achternaam"
                $credential = New-Object System.Management.Automation.PSCredential ("admin", $dccred.Password)

                $vm = New-VM -name $vmnaam -Template ws-user-temp -ResourcePool I540703 -Datastore NIM01-1 -Location I540703  
                Write-Host "VM $vmnaam aangemaakt"
                Start-Sleep -Seconds 60 

                Start-VM -VM $vmnaam
                Start-Sleep -Seconds 60

                $vm = Get-VM -Name $vmnaam
                $ipv4Adres = $vm.Guest.IPAddress | Select-Object -First 1

                Disconnect-VIServer -Server $vcenter -Force -Confirm:$false

                Invoke-Command -ComputerName $ipv4Adres -Credential $wscred -ScriptBlock {
                    Rename-Computer -NewName $using:hostname -Force -Restart
                }
                
                Start-Sleep -Seconds 90  

                Invoke-Command -ComputerName $ipv4Adres -Credential $credential -ScriptBlock {
                    winget install Google.Chrome --accept-package-agreements --accept-source-agreements --silent
                    start-sleep -seconds 30
                    Add-Computer -DomainName "mijden.lan" -Credential $using:credential -Force -Restart
                }
            } else {
                Write-Host "Gebruiker $samAccountName bestaat al."
            }
        }
        Start-Sleep -Seconds 30
    }
}
