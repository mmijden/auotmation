$vcenter = "vcenter.netlab.fontysict.nl"
$vcentercred = Import-Clixml -Path "C:\Users\admin\Documents\vcenter_credentials.xml"
$dccred = Import-Clixml -Path "C:\Users\admin\Documents\dc_credentials.xml"
$wscred = Import-CliXml -Path "C:\Users\admin\Documents\ws_credentials.xml"
$datastore = "NIM01-1"

while ($true) {
    $Response = Invoke-RestMethod http://10.3.0.40:8085/Staff
    Write-Host "Fetched data from API"

    foreach ($user in $Response.data) {
        $voornaam = $user.Voornaam
        $achternaam = $user.Achternaam
        $personeelsnummer = $user.Personeelsnummer
        $afdeling = $user.Afdeling
        $email = $user.Email
        $samAccountName = "$voornaam.$achternaam"
        $wachtwoord = [System.Web.Security.Membership]::GeneratePassword(8,2)
        $controlegebruiker = Get-ADUser -Filter {SamAccountName -eq $samAccountName}

        if ($controlegebruiker -eq $null) {
            New-ADUser -Name $voornaam -GivenName $voornaam -Surname $achternaam -SamAccountName $samAccountName -Department $afdeling -UserPrincipalName "$samAccountName@mijden.lan" -Path "OU=$afdeling,DC=mijden,DC=lan" -AccountPassword (ConvertTo-SecureString $wachtwoord -AsPlainText -Force) -Enabled $true -ChangePasswordAtLogon $true
            $vmnaam = "ws-$voornaam$achternaam"
            $hostname = "ws-$voornaam$achternaam"
            $wachtwoord = "Mike123"
            $serverNaamOfIp = "test"
            $gebruikerdc = $dccred.UserName
            $domein = "mijden.lan"
            $ip = "10.2.0.32"
            $credential = New-Object System.Management.Automation.PSCredential ("admin", $wscred.Password)

            Connect-VIServer $vcenter -Credential $vcentercred
            Start-Sleep -Seconds 60
            $vm = New-VM -Name $vmnaam -Template ws-user-temp -ResourcePool I540703 -Datastore $datastore -Location I540703
            Write-Host "VM created with name: $vmnaam"

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
            Write-Host "E-mail verstuurd naar $emailontvanger met de accountdetails."
        }
    }
    Start-Sleep -Seconds 10  
}
