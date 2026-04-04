# Sparkle Auto-Update Release Guide

## Setup (already done)

- Sparkle 2.9.0 integrated via SPM
- `SPUStandardUpdaterController` wired in AppDelegate
- `SUFeedURL` in Info.plist → `https://raw.githubusercontent.com/hbshih/lenny-lil-agents/main/appcast.xml`
- `SUPublicEDKey` in Info.plist → `8QOCrY3j4crgz4iR5lmxyv+rA5vnqK6Qtd1XheMllP8=`
- `appcast.xml` at repo root — push to `main` to publish updates

**Keep the private EdDSA key safe.** It pairs with the public key above.
If lost, rotate it: generate a new keypair with `generate_keys`, update `SUPublicEDKey`
in Info.plist, and ship a build with the new public key before publishing any updates.

---

## Releasing an update

### 1. Build, notarize, and staple

Archive the app in Xcode (Product → Archive), export a notarized `.app`,
then staple the notarization ticket:

```sh
xcrun stapler staple Lenny.app
```

### 2. Create a zip

```sh
ditto -c -k --keepParent Lenny.app Lenny-v1.1.zip
```

### 3. Sign for Sparkle

```sh
./bin/sign_update Lenny-v1.1.zip
```

This prints a `sparkle:edSignature` value and the file length. Save both.

### 4. Upload to GitHub Releases

Create a release at `https://github.com/hbshih/lenny-lil-agents/releases`
tagged `v1.1` and attach `Lenny-v1.1.zip`.

### 5. Add an item to `appcast.xml`

```xml
<item>
  <title>Version 1.1</title>
  <sparkle:version>2</sparkle:version>
  <sparkle:shortVersionString>1.1</sparkle:shortVersionString>
  <pubDate>Sat, 05 Apr 2026 00:00:00 +0000</pubDate>
  <enclosure
    url="https://github.com/hbshih/lenny-lil-agents/releases/download/v1.1/Lenny-v1.1.zip"
    sparkle:edSignature="SIGNATURE_FROM_STEP_3"
    length="FILE_LENGTH_FROM_STEP_3"
    type="application/zip" />
</item>
```

Insert inside `<channel>`, after the comment block.

### 6. Commit and push `appcast.xml`

```sh
git add appcast.xml
git commit -m "Release v1.1"
git push
```

Users on any previous version will see the update prompt automatically.

---

## Key files

| File | Purpose |
|------|---------|
| `appcast.xml` | Public update feed — commit to publish a release |
| `LilAgents/Info.plist` | `SUFeedURL` and `SUPublicEDKey` live here |
| `LilAgents/App/LilAgentsApp.swift` | `SPUStandardUpdaterController` init |
| `bin/sign_update` | Sparkle CLI tool for signing builds (from Sparkle package) |

---

## Sparkle `bin/sign_update` location

The tool ships with the Sparkle SPM package. After resolving packages, find it at:

```
~/Library/Developer/Xcode/DerivedData/.../SourcePackages/checkouts/Sparkle/bin/sign_update
```

Or run it via the Sparkle distribution download from `https://sparkle-project.org`.
