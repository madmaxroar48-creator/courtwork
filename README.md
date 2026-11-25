# Courtwork Street VR — Meta Quest 2

Godot 4.7.2 single-player basketball VR practice prototype targeting standalone Android/OpenXR on Meta Quest 2.

## Current prototype scope

- OpenXR startup and left/right Meta Touch controller action map.
- Practice court, hoop, backboard, rim collision and score trigger.
- Physics basketball with controller grab, velocity-based release and scoring.
- In-headset trainer settings for shot power, shot assistance and dribble-bounce assistance.
- Compatibility renderer and 90 Hz physics tick target.

This is an early single-player prototype. It does not yet include online multiplayer, opposing players, avatars, cosmetics, a career mode, or physical-headset quality assurance.

## Build the Quest 2 APK in GitHub

1. Upload the contents of this folder to the root of a GitHub repository. Keep the `.github/workflows` folder.
2. Open the repository's **Actions** tab.
3. Select **Build Courtwork Street VR for Quest 2** and choose **Run workflow** on `main`.
4. Wait for the run to finish successfully.
5. Open the completed run and download the `CourtworkStreetVR-Quest2-APK` artifact.
6. Extract the artifact ZIP to get `CourtworkStreetVR-Quest2.apk`.

The workflow downloads Godot 4.7.2 and matching Android export templates, installs OpenJDK 17 and the Android SDK, and exports an ARM64 Android APK with OpenXR enabled. It signs the APK using a temporary debug key for local testing/sideloading; it is not a store release. New workflow runs create a new debug key, so uninstall the old test APK before installing a later build if Android reports a signature conflict.

## Quest 2 controls

- Right grip: hold to grab the ball; release to throw.
- Right B: toggle the trainer panel.
- Right A: increase shot power.
- Left Y: decrease shot power.
- Left X: toggle shot assist.
- Left thumbstick click: toggle dribble-bounce assistance.
- Left grip: reset basketball.

Keep the Quest guardian/boundary enabled and clear the play area before testing. A successful Android export is not a substitute for testing on the physical headset.
