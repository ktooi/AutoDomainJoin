# Windows 自動ドメイン参加スクリプト

この PowerShell スクリプトは、Windows クライアントを Active Directory ドメインに参加させるプロセスを自動化します。必要なパラメータを設定ファイルで指定し、自動でドメイン参加を行うことができます。

## 特徴

- Windows クライアントを自動で AD ドメインに参加。
- ドメイン参加前に DNS サーバー設定をオプションで変更可能。
- 平文パスワードと暗号化パスワードの両方をサポート。
- 暗号化パスワードの鍵をファイルまたは Base64 エンコード文字列で指定可能。
- コンピューターアカウントの OUPath を指定可能。
- DNS 設定を行うネットワークインターフェースを指定可能。
- 設定パラメータは外部ファイルから読み込み。

## 前提条件

- Windows 10 以降。
- 管理者権限での PowerShell 実行。
- ドメインコントローラーへのネットワーク接続。

## 使用方法

### 1. リポジトリをクローンまたはダウンロード

### 2. 設定ファイルを準備

必要なパラメータを含む設定ファイル（例：`config.psd1`）を作成します。

#### 設定パラメータ

- `domain` (string): 参加するドメイン。例：`"ad.example.com"`
- `username` (string): 認証に使用するユーザー名。例：`"AD\Administrator"`
- `password` (string, 任意): 平文のパスワード。
- `securePassword` (string, 任意): 暗号化されたパスワード。
- `keyFilePath` (string, 任意): 復号化に使用する鍵ファイルのパス。
- `key` (string, 任意): Base64 エンコードされた鍵文字列。
- `OUPath` (string, 任意): コンピューターアカウントの OUPath。
- `dnsServers` (string 配列, 任意): DNS サーバーの IP アドレス。
- `interfaceNames` (string 配列, 任意): ネットワークインターフェース名。

**注意**: `password` と `securePassword` のいずれか一方を指定する必要があります。

#### 設定ファイルの例

```powershell
@{
    domain = "ad.example.com"
    username = "AD\Administrator"

    # オプション 1: 平文のパスワードを使用
    #password = "YourPasswordHere"

    # オプション 2: 暗号化パスワードを使用
    securePassword = "暗号化されたパスワード文字列"

    # 鍵の指定（任意）
    # オプション A: 鍵ファイルのパスを指定
    #keyFilePath = "C:\secure\encryptionkey.key"

    # オプション B: Base64 エンコードされた鍵文字列を直接指定
    #key = "Base64EncodedKeyString"

    # OUPath の指定（任意）
    OUPath = "CN=Computers,DC=ad,DC=example,DC=com"

    # DNS サーバー（任意）
    dnsServers = @("192.168.0.1")

    # インターフェース名（任意）
    interfaceNames = @("Ethernet", "Wi-Fi")
}
```

### 3. スクリプトを実行

管理者権限で PowerShell を開き、以下のコマンドを実行します。

```powershell
.\AutoDomainJoin.ps1 -ConfigFilePath ".\config.psd1"
```

`-ConfigFilePath` パラメータを指定しない場合、デフォルトで `.\config.psd1` が使用されます。

## パスワードと鍵の取り扱い

### オプション 1: 鍵情報を設定ファイルに記載する方法

#### 鍵の生成とパスワードの暗号化

1. **鍵の生成**

   ```powershell
   # 鍵を生成し、Base64 エンコード
   $key = New-Object Byte[] 32
   [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($key)
   $keyBase64 = [Convert]::ToBase64String($key)
   ```

2. **パスワードの暗号化**

   ```powershell
   # Base64 エンコードされた鍵を使用してパスワードを暗号化
   $key = [Convert]::FromBase64String($keyBase64)
   $secureString = Read-Host -AsSecureString -Prompt "パスワードを入力してください"
   $encryptedPassword = $secureString | ConvertFrom-SecureString -Key $key
   ```

3. **設定ファイルへの記載**

   - `securePassword` に `$encryptedPassword` の値を設定。
   - `key` に `$keyBase64` の値を設定。

#### 設定ファイルの例

```powershell
@{
    domain = "ad.example.com"
    username = "AD\Administrator"
    securePassword = "暗号化されたパスワード文字列"
    key = "Base64EncodedKeyString"
    # その他のパラメータ...
}
```

### オプション 2: 鍵情報を別ファイルに保存する方法

#### 鍵の生成と保存

1. **鍵の生成**

   ```powershell
   # 鍵を生成
   $key = New-Object Byte[] 32
   [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($key)
   ```

2. **鍵の保存**

   ```powershell
   # 鍵をファイルに保存
   $key | Set-Content -Path "C:\secure\encryptionkey.key" -Encoding Byte
   ```

#### パスワードの暗号化

```powershell
# 鍵を読み込み
$key = Get-Content -Path "C:\secure\encryptionkey.key" -Encoding Byte
$secureString = Read-Host -AsSecureString -Prompt "パスワードを入力してください"
$encryptedPassword = $secureString | ConvertFrom-SecureString -Key $key
```

#### 設定ファイルへの記載

- `securePassword` に `$encryptedPassword` の値を設定。
- `keyFilePath` に鍵ファイルのパスを設定。

#### 設定ファイルの例

```powershell
@{
    domain = "ad.example.com"
    username = "AD\Administrator"
    securePassword = "暗号化されたパスワード文字列"
    keyFilePath = "C:\secure\encryptionkey.key"
    # その他のパラメータ...
}
```

## セキュリティに関する注意事項

- **パスワードの取り扱い**: 平文でパスワードを保存することは安全ではありません。暗号化パスワードの使用を推奨します。
- **鍵の管理**: 鍵は安全に保管し、不正なアクセスを防止してください。
- **アクセス制御**: 設定ファイルや鍵ファイルには適切なファイル権限を設定してください。

## ライセンス

このプロジェクトは MIT ライセンスの下で提供されています。
