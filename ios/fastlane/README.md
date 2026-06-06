# iOS fastlane

Distribution lanes for the Provii wallet iOS app. Single bundle
(`app.provii.wallet`) for every audience, runtime environment toggle inside
the app.

## Lanes

| Lane    | Purpose                                                     |
|---------|-------------------------------------------------------------|
| `beta`  | Build, sign, Sigstore attest, upload to TestFlight          |
| `release` | Submit the latest TestFlight build to App Store review (skeleton, kept for the first store launch) |

## Local prerequisites

1. Ruby 3.2 with bundler installed (`brew install ruby@3.2` then `gem install bundler`).
2. Xcode 16.x with command-line tools.
3. Cosign (`brew install cosign`) for the Sigstore attestation step.
4. CocoaPods (handled automatically by `bundle install`).

```
cd ios
bundle install
bundle exec pod install
```

## Code signing

We use the manual fastlane flow (`get_certificates` + `get_provisioning_profile`)
rather than `match`. `match` requires keeping signing material in a shared git
repo, which conflicts with the wallet repo's "no secrets in version control"
rule. The manual flow uses an App Store Connect API key plus an ephemeral
keychain on each CI run.

## App Store Connect API key

Generate the key once at
**App Store Connect -> Users and Access -> Integrations -> Team Keys**, role
`App Manager` (minimum required for TestFlight upload + delivery).

The key download is a `.p8` file plus a key id and an issuer id. Encode the
three values into a single JSON document, then base64-encode the document for
storage as a GitHub Actions secret named `APP_STORE_CONNECT_API_KEY_JSON`.

Example payload (decoded form, before base64):

```
{
  "key_id":   "ABCD123456",
  "issuer_id": "00000000-0000-0000-0000-000000000000",
  "key": "-----BEGIN PRIVATE KEY-----\nMIGTAgEAMB...\n-----END PRIVATE KEY-----"
}
```

Encode for CI:

```
base64 -i app_store_connect_key.json | pbcopy
```

Paste the result into the GitHub secret value field. The `APP_STORE_CONNECT_API_KEY_JSON`
form is decoded and parsed inside the `Fastfile` helper `load_app_store_connect_api_key`.

For local runs, the `_PATH` variant works too:

```
export APP_STORE_CONNECT_API_KEY_PATH=/path/to/AuthKey_ABCD123456.p8
export APP_STORE_CONNECT_API_KEY_ID=ABCD123456
export APP_STORE_CONNECT_API_KEY_ISSUER_ID=00000000-0000-0000-0000-000000000000
```

## Run the beta lane locally

```
cd ios
bundle exec fastlane beta
```

A local run requires a real App Store Connect API key. Tim should keep his
local `.p8` outside the repo and rely on the env variables above.

## Run the beta lane in CI

The `.github/workflows/ios-testflight.yml` workflow calls `bundle exec fastlane beta`
on push of a `v*` tag and on `workflow_dispatch`. Required GitHub secrets:

| Secret                                | Purpose                                          |
|---------------------------------------|--------------------------------------------------|
| `APP_STORE_CONNECT_API_KEY_JSON`      | Base64-encoded API key payload                   |
| `IOS_KEYCHAIN_PASSWORD`               | Ephemeral keychain unlock password               |
| `SLACK_WEBHOOK_URL`                   | Optional, suppresses the post if absent          |

## What Tim still needs to do

1. Generate the App Store Connect API key in Apple Developer portal and paste
   the base64-encoded JSON into `APP_STORE_CONNECT_API_KEY_JSON`.
2. Fill `APPLE_ID` (account email) and `ITC_TEAM_ID` (numeric ASC team id) in
   the workflow env or local shell.
3. The first TestFlight upload triggers Beta App Review. Apple requires
   reviewer notes, contact details, and a sign-in credential pair if the app
   gates content behind login. Submit those fields via App Store Connect web UI
   the first time.
4. Confirm the App Store Connect record exists with bundle id
   `app.provii.wallet`. If not, create it under
   **App Store Connect -> Apps -> +**.

The Apple Developer team id (`FD5A2PXL3W`) is already wired into the project
file and the `Appfile`. No action needed there.
