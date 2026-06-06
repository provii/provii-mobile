# Android fastlane

Distribution lane for the Provii wallet Android app. One lane: `beta`, which
builds a signed release AAB and uploads it to Firebase App Distribution.

Single-bundle architecture: package id `app.provii.wallet` for every audience,
runtime environment toggle inside the app.

## Lanes

| Lane   | Purpose                                                            |
|--------|--------------------------------------------------------------------|
| `beta` | Build signed release AAB, generate release notes, upload to FAD    |

## Local prerequisites

1. Ruby 3.2 with bundler.
2. JDK 17 (`brew install temurin@17`).
3. Android command-line tools or Android Studio installed locally.
4. A release keystore (or local debug keystore for smoke tests).

```
cd android
bundle install
bundle exec fastlane install_plugins
```

## Firebase service account

Create a service account in
**Google Cloud Console -> IAM and Admin -> Service Accounts**, then grant the
**Firebase App Distribution Admin** role under the Firebase project. Download
the JSON key.

For CI, base64-encode the JSON and store it in a GitHub Actions secret named
`FIREBASE_APP_DISTRIBUTION_CREDENTIALS_JSON`. The workflow decodes it to a
temp file and exports `FIREBASE_APP_DISTRIBUTION_CREDENTIALS_PATH` before
calling the lane.

```
base64 -i firebase-fad-service-account.json | pbcopy
```

For local runs, point the path env variable at the decoded file:

```
export FIREBASE_APP_DISTRIBUTION_CREDENTIALS_PATH=/path/to/firebase-fad-service-account.json
export FIREBASE_APP_ID=1:1234567890:android:abcdef
```

## Tester groups

The lane uploads to two tester groups, both of which must already exist in
**Firebase console -> App Distribution -> Testers and Groups**:

| Group                  | Audience                                            |
|------------------------|-----------------------------------------------------|
| `provii-internal`      | Provii engineers + immediate stakeholders           |
| `provii-external-beta` | Invited issuer partners + community testers         |

Tim should populate the rosters via the Firebase console before the first
beta build is uploaded; the lane itself does not manage tester membership.

## Release notes

Auto-generated from the git log between the previous tag (or HEAD~10 if no
tag exists yet) and HEAD. Truncated to 500 characters because Firebase App
Distribution rejects longer release-note bodies. Written to
`fastlane/release_notes.txt`, which the FAD gradle plugin and the fastlane
action both read.

## Run the beta lane locally

```
cd android
bundle exec fastlane beta
```

## Run the beta lane in CI

`.github/workflows/android-fad.yml` calls `bundle exec fastlane beta` on push
of any `v*` tag and on `workflow_dispatch`. Required GitHub secrets:

| Secret                                            | Purpose                          |
|---------------------------------------------------|----------------------------------|
| `FIREBASE_APP_DISTRIBUTION_CREDENTIALS_JSON`      | Base64-encoded service-account JSON |
| `FIREBASE_APP_ID`                                 | Firebase application id (`1:.../android:...`) |
| `ANDROID_SIGNING_KEY`                             | Base64-encoded release `.jks`    |
| `ANDROID_KEY_ALIAS`                               | Release key alias                |
| `ANDROID_KEYSTORE_PASSWORD`                       | Release keystore password        |
| `ANDROID_KEY_PASSWORD`                            | Release key password             |
| `SLACK_WEBHOOK_URL`                               | Optional Slack notification URL  |

## What Tim still needs to do

1. Create the Firebase project (or confirm one already exists). The package
   `app.provii.wallet` must be registered as an Android app inside the
   project; Firebase issues the `FIREBASE_APP_ID` value at creation time.
2. Generate the Firebase App Distribution Admin service-account key and paste
   the base64-encoded JSON into the `FIREBASE_APP_DISTRIBUTION_CREDENTIALS_JSON`
   GitHub secret.
3. Populate the `provii-internal` and `provii-external-beta` tester rosters
   via the Firebase console.
4. Generate the release keystore (or onboard onto Play App Signing) and
   populate the four `ANDROID_*` keystore secrets.
