# AGENTS.md

Guidance for AI agents (and humans) working in this repository. It records the
conventions and the hard-won constraints, so they do not have to be rediscovered.

## What this is

A Flutter client for **Headscale**, the self-hosted Tailscale control server.
It is a *remote administration* client: the phone talks to Headscale over the
network and is **not** a member of the tailnet. Android is the only automated
build target; iOS/macOS/Web/Windows compile but are not built by CI.

## Hard rules

1. **The version number lives in three places** and must stay in sync:
   `pubspec.yaml`, the `currentVersion` literal in `lib/screens/home_screen.dart`
   (it gates the What's New dialog), and the newest entry in
   `lib/data/whats_new_data.dart`. Bumping only `pubspec.yaml` means returning
   users never see the release notes.
2. **Every user-visible string goes through `l10n.t(fr, en, zh)`** — French
   first, then English, then Chinese. `zh` may be omitted (falls back to `en`).
   No bare literals in widgets; `context.l10n` is available via the extension in
   `lib/l10n/l10n.dart`.
3. **`dart analyze` is the analyzer**, not `flutter analyze` — the latter's LSP
   analyzer crashes on non-ASCII paths. Expect `No issues found!`.
4. **Never commit the churn produced by `flutter pub get`**:
   `analysis_options.yaml`, `pubspec.lock`, and the `linux/macos/windows`
   registrant files. Revert them before committing.
5. **Line endings are CRLF.** Scripts that rewrite files must preserve them
   (`open(..., newline='')` / `newline=''` when writing).
6. **Do not "fix" the signing by trusting Gradle.** AGP refuses to emit a v1
   (JAR) signature for `minSdk >= 24`, and its debug keystore differs per run.
   The release workflow re-signs with `apksigner` instead — keep it that way.

## Repository layout

| Path | Contents |
|---|---|
| `lib/api/headscale_api_service.dart` | The only place that talks to Headscale. `ApiOperation` enum + `HeadscaleApiException` keep error text localizable without affecting logic. |
| `lib/models/` | Plain models with `fromJson`; see `node.dart` for the network fields. |
| `lib/screens/`, `lib/widgets/` | UI. Comments here are French (existing style). |
| `lib/services/` | Logic that is worth testing without a widget: ACL generation, DERP probing, notifications, tag migration. |
| `lib/l10n/l10n.dart` | The whole i18n layer (no ARB/intl/codegen, deliberately). |
| `test/` | 61 tests. Pure logic and widget tests both live here. |
| `.github/workflows/` | `android.yml` (CI) and `release.yml` (tag → GitHub Release). |

## Build, test, release

```bash
flutter pub get
dart analyze          # must print "No issues found!"
flutter test          # 61 tests
flutter build apk --release
```

* **CI** (`android.yml`): analyze + test → build APK → **signature gate**
  (requires a `META-INF/*.RSA` entry and `apksigner verify --min-sdk-version 21`
  to pass) → upload artifact.
* **Release** (`release.yml`): push a `v*` tag (or dispatch it with a `tag`
  input) → analyze + test → build the universal **and** per-ABI APKs → re-sign
  each with v1+v2+v3 → create the GitHub Release with every APK attached, the
  body taken from `RELEASE_NOTES.md`.
* **Signing keys** come from the repository secrets
  (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
  `ANDROID_KEY_PASSWORD`). Without them CI generates a key and caches it. The
  keystore is the *only* key that can update an installed copy — back it up.
* **Release checklist**: bump the three version places → add a What's New entry →
  rewrite `RELEASE_NOTES.md` → commit → push → tag → verify the release assets,
  their byte sizes and the signer fingerprint (`CN=Headscale Manager`).
* Ship **per-ABI APKs** with every release. The universal APK is ~70 MB and a
  truncated download loses the signature block at the end of the file, which
  installers report as "package has no signature file" — indistinguishable from
  a build that was never signed.

### Network notes (this environment)

* GitHub may be unreachable: use `git -c http.sslBackend=openssl` (schannel
  fails) and the local proxy `http://127.0.0.1:10808` when pushing.
* Write commit messages to a file and use `git commit -F <file>`: inline
  PowerShell quoting breaks on `"` and turns parts of the message into pathspecs.

## Data-source boundaries — what the app can and cannot read

Verified against Headscale **v0.29.4** (proto RPCs + `hscontrol/app.go` routes).

**Available**

* 29 authenticated `/api/v1/*` endpoints: users, nodes (`list/get/rename/
  expire/delete/register/backfillips`, `tags`, `approve_routes`), pre-auth keys,
  API keys, policy (`get/set/check`), health.
* Public, no API key: `GET /version`, `GET /health`, `GET /swagger/v1/
  openapiv2.json`, and — when embedded DERP is enabled — `GET /bootstrap-dns`,
  `GET /derp/probe`, `GET /derp/latency-check`.
* Node fields: `id, machineKey, nodeKey, discoKey, ipAddresses, name, user,
  lastSeen, expiry, preAuthKey, createdAt, registerMethod, givenName, online,
  approvedRoutes, availableRoutes, subnetRoutes, tags`.

**Not available, and why**

* **DNS/MagicDNS settings** (`dns.base_domain`, `nameservers`,
  `extra_records`): they live in Headscale's `config.yaml`; there is **no DNS
  endpoint**. Headplane can edit them only because it writes that file directly.
  The app should offer a manual base-domain setting instead.
* **Per-node OS / client version / endpoints / DERP relay**: available, but from
  the **device API**, not the node API. `GET /api/v1/device/{id}` returns `os`,
  `clientVersion`, `authorized` and a `client_connectivity` block carrying
  `endpoints`, `derp` (the relay in use) and `latency` (per-region, measured by
  the client itself). This has existed since 0.29 - do not repeat the earlier
  mistake of concluding "unobtainable" from `node.proto` alone: `host_info` and
  `endpoints` really are `reserved` there, but `device.proto` defines the richer
  messages while `headscale.proto` defines the service. Hide the UI when the
  endpoint 404s, i.e. on older servers.
* `POST /api/v1/policy/check` returns an **empty body**: the HTTP status carries
  the verdict and the parse error text is in the response body.
* Do **not** ping node Tailscale addresses (`100.64.0.0/10`) from the app — the
  phone is not in the tailnet, so they are unreachable. Use the API's
  `online`/`lastSeen`, and measure latency to the server or its DERP instead.

## Working agreements

* Prefer the smallest change that solves the problem; keep unrelated churn out.
* Add a test for any new pure logic, and run `dart analyze` + `flutter test`
  before committing.
* When a claim can be checked against the server or the upstream source, check
  it instead of guessing — several bugs in this repository's history came from
  assumptions about the API (see `../headscalemanager-中文本地化分析.md`).
