# Windows Auto Domain Join Script

This PowerShell script automates the process of joining a Windows client to an Active Directory domain. It allows you to specify required parameters in a configuration file and perform the domain join automatically.

## Features

- Automatically join a Windows client to an AD domain.
- Optionally change DNS server settings before joining.
- Supports both plain text and encrypted passwords.
- Allows specifying the encryption key via file or directly as a Base64-encoded string.
- Ability to specify the OUPath for the computer account.
- Allows specifying network interfaces for DNS configuration.
- Configuration parameters are loaded from an external file.

## Prerequisites

- Windows 10 or later.
- PowerShell with administrative privileges.
- Network connectivity to the domain controller.

## Usage

### 1. Clone or download this repository

### 2. Prepare the configuration file

Create a configuration file (e.g., `config.psd1`) with the necessary parameters.

#### Configuration Parameters

- `domain` (string): The domain to join. Example: `"ad.example.com"`
- `username` (string): The username for authentication. Example: `"AD\Administrator"`
- `password` (string, optional): The plain text password.
- `securePassword` (string, optional): The encrypted password.
- `keyFilePath` (string, optional): The path to the key file for decryption.
- `key` (string, optional): Base64-encoded key string.
- `OUPath` (string, optional): OU path for the computer account.
- `dnsServers` (array of strings, optional): DNS server IP addresses.
- `interfaceNames` (array of strings, optional): Network interface names.

**Note**: Either `password` or `securePassword` must be specified.

#### Example Configuration File

```powershell
@{
    domain = "ad.example.com"
    username = "AD\Administrator"

    # Option 1: Use plain text password
    #password = "YourPasswordHere"

    # Option 2: Use secure password
    securePassword = "YourEncryptedPasswordString"

    # Key specification (optional)
    # Option A: Specify key file path
    #keyFilePath = "C:\secure\encryptionkey.key"

    # Option B: Specify key directly as Base64-encoded string
    #key = "Base64EncodedKeyString"

    # OUPath specification (optional)
    OUPath = "CN=Computers,DC=ad,DC=example,DC=com"

    # DNS servers (optional)
    dnsServers = @("192.168.0.1")

    # Interface names (optional)
    interfaceNames = @("Ethernet", "Wi-Fi")
}
```

### 3. Run the script

Open PowerShell with administrative privileges and execute the script:

```powershell
.\AutoDomainJoin.ps1 -ConfigFilePath ".\config.psd1"
```

If you do not specify the `-ConfigFilePath` parameter, it defaults to `.\config.psd1`.

## Handling of Passwords and Keys

### Option 1: Specifying Key Information in the Configuration File

#### Generating the Key and Encrypting the Password

1. **Generate the Key**

   ```powershell
   # Generate a key and encode it in Base64
   $key = New-Object Byte[] 32
   [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($key)
   $keyBase64 = [Convert]::ToBase64String($key)
   ```

2. **Encrypt the Password**

   ```powershell
   # Use the Base64-encoded key to encrypt the password
   $key = [Convert]::FromBase64String($keyBase64)
   $secureString = Read-Host -AsSecureString -Prompt "Enter Password"
   $encryptedPassword = $secureString | ConvertFrom-SecureString -Key $key
   ```

3. **Update the Configuration File**

   - Set `securePassword` to the value of `$encryptedPassword`.
   - Set `key` to the value of `$keyBase64`.

#### Example Configuration File

```powershell
@{
    domain = "ad.example.com"
    username = "AD\Administrator"
    securePassword = "YourEncryptedPasswordString"
    key = "Base64EncodedKeyString"
    # Other parameters...
}
```

### Option 2: Storing Key Information in a Separate File

#### Generating and Saving the Key

1. **Generate the Key**

   ```powershell
   # Generate a key
   $key = New-Object Byte[] 32
   [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($key)
   ```

2. **Save the Key**

   ```powershell
   # Save the key to a file
   $key | Set-Content -Path "C:\secure\encryptionkey.key" -Encoding Byte
   ```

#### Encrypting the Password

```powershell
# Read the key from the file
$key = Get-Content -Path "C:\secure\encryptionkey.key" -Encoding Byte
$secureString = Read-Host -AsSecureString -Prompt "Enter Password"
$encryptedPassword = $secureString | ConvertFrom-SecureString -Key $key
```

#### Update the Configuration File

- Set `securePassword` to the value of `$encryptedPassword`.
- Set `keyFilePath` to the path of the key file.

#### Example Configuration File

```powershell
@{
    domain = "ad.example.com"
    username = "AD\Administrator"
    securePassword = "YourEncryptedPasswordString"
    keyFilePath = "C:\secure\encryptionkey.key"
    # Other parameters...
}
```

## Security Considerations

- **Password Handling**: Storing passwords in plain text is insecure. It is recommended to use encrypted passwords.
- **Key Management**: Keep the key secure and prevent unauthorized access.
- **Access Control**: Secure the configuration and key files by setting appropriate file permissions.

## License

This project is licensed under the MIT License.
