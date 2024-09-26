# ---------------------------------------------
# Script to Change DNS Settings and Join Domain
# ---------------------------------------------

# Parse script arguments
param (
    [string]$ConfigFilePath = ".\config.psd1"
)

# Set the error action preference to stop on all errors
$ErrorActionPreference = "Stop"

# Check if the configuration file exists
if (-Not (Test-Path $ConfigFilePath)) {
    Write-Error "Configuration file not found at path: $ConfigFilePath"
    Exit 1
}

# Import parameters from the configuration file
$config = Import-PowerShellDataFile -Path $ConfigFilePath

# Retrieve parameters from the configuration
$domain = $config.domain
$username = $config.username
$password = $config.password  # Plain text password (optional)
$securePassword = $config.securePassword  # Encrypted password (optional)
$keyFilePath = $config.keyFilePath  # Path to key file for decryption (optional)
$keyBase64 = $config.key  # Base64-encoded key string (optional)
$OUPath = $config.OUPath  # OU path for computer account (optional)
$dnsServers = $config.dnsServers  # Array of DNS server IP addresses (optional)
$interfaceNames = $config.interfaceNames  # Array of interface names (optional)

# Validate password input
if (-Not $password -and -Not $securePassword) {
    Write-Error "Either 'password' or 'securePassword' must be specified in the configuration file."
    Exit 1
}

# Create a secure password
if ($securePassword) {
    # If key is specified, use it to decrypt the password
    if ($keyFilePath -or $keyBase64) {
        if ($keyFilePath) {
            # Read key from file
            if (-Not (Test-Path $keyFilePath)) {
                Write-Error "Key file not found at path: $keyFilePath"
                Exit 1
            }
            $key = Get-Content -Path $keyFilePath -Encoding Byte
        } elseif ($keyBase64) {
            # Decode Base64-encoded key from configuration
            try {
                $key = [Convert]::FromBase64String($keyBase64)
            } catch {
                Write-Error "Failed to decode the key from Base64 string. Error: $_"
                Exit 1
            }
        }

        # Decrypt the secure password using the key
        try {
            $securePassword = $securePassword | ConvertTo-SecureString -Key $key
        } catch {
            Write-Error "Failed to decrypt the secure password with the provided key. Error: $_"
            Exit 1
        }
    } else {
        # Decrypt the secure password without a key
        $securePassword = $securePassword | ConvertTo-SecureString
    }
} else {
    # Convert plain text password to a secure string
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
}

# Create a credential object
$credential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)

# Function to change DNS settings
function Set-DnsServers {
    param (
        [string[]]$DnsServers,
        [string[]]$InterfaceNames
    )
    Write-Host "Setting DNS servers..." -ForegroundColor Cyan

    # Get available network adapters
    $networkAdapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' }

    $interfaceToUse = $null

    if ($InterfaceNames -and $InterfaceNames.Count -gt 0) {
        foreach ($name in $InterfaceNames) {
            $adapter = $networkAdapters | Where-Object { $_.Name -eq $name }
            if ($adapter) {
                $interfaceToUse = $adapter
                break
            }
        }
        if (-Not $interfaceToUse) {
            Write-Warning "No matching network interface found in the specified names. Using the first available interface."
        }
    }

    if (-Not $interfaceToUse) {
        $interfaceToUse = $networkAdapters | Select-Object -First 1
    }

    if ($interfaceToUse) {
        try {
            Set-DnsClientServerAddress -InterfaceIndex $interfaceToUse.IfIndex -ServerAddresses $DnsServers
            Write-Host "DNS servers set to: $($DnsServers -join ', ') on interface '$($interfaceToUse.Name)'" -ForegroundColor Green
        } catch {
            Write-Error "Failed to set DNS servers on interface '$($interfaceToUse.Name)'. Error: $_"
            Exit 1
        }
    } else {
        Write-Error "No network interface found to set DNS servers."
        Exit 1
    }
}

# Change DNS settings if dnsServers is specified
if ($dnsServers -and $dnsServers.Count -gt 0) {
    Set-DnsServers -DnsServers $dnsServers -InterfaceNames $interfaceNames
} else {
    Write-Host "No DNS servers specified. Skipping DNS configuration." -ForegroundColor Yellow
}

# Join the computer to the domain
Try {
    # Build the parameters for Add-Computer
    $addComputerParams = @{
        DomainName = $domain
        Credential = $credential
        Verbose    = $true
        Force      = $true
    }

    # Include OUPath if specified
    if ($OUPath) {
        $addComputerParams['OUPath'] = $OUPath
    }

    Add-Computer @addComputerParams

    Write-Host "Successfully joined the domain. Restarting the computer..." -ForegroundColor Green

    # Restart the computer to complete the domain join
    # Restart-Computer -Force
}
Catch {
    Write-Error "Failed to join the domain. Error: $_"
}
