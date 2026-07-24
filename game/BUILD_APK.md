# Build the Android APK

## Fastest method - GitHub Actions

1. Create an empty GitHub repository.
2. Upload this complete project to the repository root.
3. Open the repository's **Actions** tab.
4. Select **Build Android APK**.
5. Choose **Run workflow**.
6. After the run finishes, download the `NilesideCity-Android-Debug` artifact.
7. Extract the ZIP and install `NilesideCity-debug.apk` on the Android phone.

The included workflow installs Java and the Android SDK, downloads Godot 4.7.1 and matching export templates, exports an arm64 debug APK, and stores it as a workflow artifact.

## Local Godot method

Requirements:

- Godot 4.7.1
- Matching Godot 4.7.1 export templates
- OpenJDK 17
- Android SDK platform 35 and build tools 35.0.0

Open `project.godot`, allow assets to import, then use:

`Project > Export > Android Debug > Export Project`

The default output is:

`builds/NilesideCity-debug.apk`
