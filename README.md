# 📍 NodeLink

NodeLink is a modern, real-time live location tracking application built with Flutter and Firebase. Designed with a heavy emphasis on battery efficiency, NodeLink acts as a secure bridge to share GPS coordinates between devices seamlessly in the background.

## 🌟 Key Features

*   **Adaptive Battery Saver:** Integrates physical activity recognition to dynamically adjust GPS polling. The app checks location every 10 minutes when sitting still, and switches to 1-minute intervals when walking or driving.
*   **Real-Time Synchronization:** Utilizes Firebase Realtime Database to push instant location updates from the sender node to the receiver node.
*   **Background Execution:** Designed to keep the location-sharing process alive even when the application is minimized or the screen is locked.
*   **Master Power Switch:** A single, prominent UI toggle giving users absolute control to instantly kill all background tracking for privacy and power saving.
*   **Modern UI/UX:** Built with Material 3 design principles for a clean, floating dashboard experience.

## 🛠️ Tech Stack

*   **Frontend Framework:** [Flutter](https://flutter.dev/) (Dart)
*   **Backend & Database:** [Firebase Realtime Database](https://firebase.google.com/)
*   **Maps Integration:** Google Maps SDK
*   **IDE:** Android Studio

## 🧠 How It Works (The Architecture)

NodeLink operates by treating connected devices as data nodes. Instead of maintaining heavy, constant GPS connections, the application relies on the device's built-in accelerometer to determine physical state (`STILL` vs `MOVING`). 

1. **The Sender:** Reads the GPS coordinate based on the adaptive timer and pushes a lightweight JSON payload (Latitude, Longitude, Timestamp) to Firebase.
2. **The Server:** Firebase Realtime Database instantly registers the data change.
3. **The Receiver:** Maintains a lightweight WebSocket connection to Firebase, instantly downloading the new coordinates and updating the map marker on the UI.
