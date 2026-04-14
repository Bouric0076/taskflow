# taskflow

A new Flutter project.

## GitHub Release (Android Downloads)

This repository includes a GitHub Actions workflow that builds Android release files and attaches them to a GitHub Release.

### What gets uploaded

- ARM 32-bit APK
- ARM 64-bit APK
- x86_64 APK
- Android App Bundle (`.aab`)
- `SHA256SUMS.txt` checksum file

### How to create a release

1. Commit and push your changes.
2. Update the app version in `pubspec.yaml` (example: `version: 1.0.1+2`).
3. Create and push a version tag:

```bash
git tag v1.0.1
git push origin v1.0.1
```

4. Open your repository on GitHub.
5. Go to **Releases** and you will see the new release with downloadable assets.

You can also run the workflow manually from the **Actions** tab using **workflow_dispatch** and provide a tag name.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
