# Local Authenticator pour macOS

Application macOS SwiftUI type Google/Microsoft Authenticator, avec stockage local des clés dans le Keychain macOS.

## Fonctionnalités incluses

- Scan de QR code via webcam avec `AVFoundation`
- Ajout manuel d'une clé secrète Base32
- Parsing des URI `otpauth://totp/...`
- Génération de codes TOTP localement
- Support SHA1, SHA256, SHA512
- Support 6, 7 ou 8 chiffres
- Support périodes 15, 30 ou 60 secondes
- Stockage local des secrets dans le Keychain
- Déverrouillage au lancement via Touch ID ou mot de passe macOS
- Copie rapide du code dans le presse-papiers
- Suppression d'un compte via clic droit

## Ouvrir le projet

### Option rapide

1. Ouvre `Package.swift` avec Xcode.
2. Sélectionne le schéma `LocalAuthenticator`.
3. Lance l'app.

### Pour une vraie app macOS sandboxée

Swift Package Manager est pratique pour développer vite, mais pour distribuer proprement l'app, crée un projet Xcode macOS App :

1. Xcode > File > New > Project > macOS > App.
2. Nom : `LocalAuthenticator`.
3. Interface : SwiftUI.
4. Language : Swift.
5. Glisse les fichiers du dossier `Sources/LocalAuthenticator` dans le projet Xcode.
6. Ajoute `SupportingFiles/Info.plist` ou copie `NSCameraUsageDescription` dans l'Info du target.
7. Dans Signing & Capabilities : active `App Sandbox` puis coche `Camera`.
8. Utilise `SupportingFiles/LocalAuthenticator.entitlements` comme référence pour les entitlements.

## Important sécurité

- Les secrets ne sont pas stockés dans `UserDefaults`.
- Les secrets ne sont pas hashés : TOTP nécessite la clé originale pour recalculer les codes.
- Les secrets sont encodés dans des objets `OTPAccount` puis stockés dans le Keychain local macOS.
- Les items Keychain utilisent `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- L'app définit `kSecAttrSynchronizable` à `false`, donc elle ne demande pas la synchronisation iCloud.
- Les comptes sont chargés uniquement après l'authentification locale au lancement.
- Après copie, le code TOTP est retiré du presse-papiers après un court délai seulement si le presse-papiers contient toujours ce code.
- Ne loggue jamais une URI `otpauth://`, car elle contient le secret.

## À améliorer ensuite

- Export/import chiffré
- App de barre de menu
- Recherche plus avancée
- Icônes par service

## Structure

```text
Sources/LocalAuthenticator/
  LocalAuthenticatorApp.swift
  Models/
    OTPAccount.swift
    OTPAlgorithm.swift
  Services/
    AppUnlockState.swift
    AccountValidator.swift
    AccountStore.swift
    Base32.swift
    ClipboardCodeCopier.swift
    KeychainStore.swift
    LaunchAuthenticator.swift
    OTPAuthParser.swift
    TOTPGenerator.swift
  Views/
    AccountRowView.swift
    AddAccountView.swift
    ContentView.swift
    LaunchAuthenticationView.swift
    QRScannerView.swift
```
