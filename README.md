# PetPause: Pause, Breathe, and Calm

PetPause is a mobile application designed to provide accessible mental health support and promote emotional well-being through interactive features and AI assistance.

## Problem Statement

Mental health issues like depression, anxiety, and stress are increasingly prevalent globally. Stigma and limited access to resources prevent many individuals from seeking necessary help. With over 280 million people affected by depression alone, there is a critical need for accessible and supportive mental wellness solutions. PetPause aims to address this gap by offering immediate access to mental health resources, fostering daily engagement through a virtual companion, and bridging the path to professional care.

## SDG Alignment

This project directly aligns with **UN Sustainable Development Goal 3: Good Health and Well-Being**. Specifically, it contributes to:
*   **Target 3.4:** Promoting mental health and well-being by encouraging proactive self-care.
*   **Target 3.8:** Improving access to essential health-care services through digital means.

## Solution Overview

PetPause is a Flutter-based mobile application that serves as a digital companion for mental wellness. It utilizes Firebase for backend services (data storage, authentication) and integrates Google's Gemini AI for interactive chat support.

## Features

*   **Virtual Pet:** A central interactive pet whose appearance changes based on its happiness level, reflecting user engagement.
*   **Daily Check-In:** Log daily feelings, view entries on a calendar, and earn coins for pet customization.
*   **Help Section:** Provides quick access to helplines, counseling services, and nearby hospitals (via Google Maps integration) with direct call, email, and WhatsApp options.
*   **Pet Tasks:** Engage in simple activities like feeding the pet or writing in the diary to earn coins, relieve stress, and increase the pet's happiness.
*   **Stress Assessments:** Complete tests to receive scores, results, and helpful tips. Results are tracked over time.
*   **My Diary:** A private digital journal for personal reflection.
*   **Pet Interaction:** Buttons for quick interactions like playing with or talking to the pet.
*   **Mental Health Tips:** Access self-care practices and healthy habits with step-by-step guidance and links to further resources.
*   **AI-Powered Chat:** Talk to your pet via a chat bar, powered by Gemini AI. Includes safety alerts for concerning keywords and stores chat history.
*   **User Profile:** Update display name and profile picture.
*   **Settings:** View account information, reset password (via email or current password), and delete account.
*   **Time Management:** Track app usage frequency to promote digital self-awareness.
*   **App Language:** Options for English, Malay, and Mandarin (Note: Malay and Mandarin translations are planned for future updates).

## Showcase / How It Works

1.  **Registration/Login:** User data is securely stored in Firebase.
2.  **Home Screen:** Users are greeted by their virtual pet, surrounded by interactive features. The pet's appearance reflects its happiness.
3.  **Interaction:** Users can engage with features like Check-In, Pet Tasks, Diary, and AI Chat.
4.  **Support:** The Help section provides immediate connections to external resources.
5.  **Personalization:** Earn coins through activities to (eventually) customize the pet.
6.  **Management:** Access profile, settings, and account management options via the top-right menu.

## Architecture

*   **Frontend:** Flutter
*   **Backend:** Firebase (Authentication, Firestore/Realtime Database)
*   **AI:** Google Gemini API
*   **Mapping:** Google Maps API
*   **Communication:** Gmail API (for password reset emails)

## Our Goal

PetPause aims to be more than just an app; it's designed to be a digital companion that heals, supports, and grows with its users. We strive to create a space where individuals feel heard, understood, and motivated to prioritize their mental well-being daily.

## Getting Started (Environment Setup)

This project is built with Flutter. To run the application locally:

1.  **Ensure Flutter is installed:** Follow the official [Flutter installation guide](https://docs.flutter.dev/get-started/install).
2.  **Clone the repository:**
    ```bash
    git clone <your-repository-url>
    cd flutter-project # Or your project directory name
    ```
3.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
4.  **Set up Firebase:**
    *   Create a Firebase project at [https://console.firebase.google.com/](https://console.firebase.google.com/).
    *   Register your Android and/or iOS app with the Firebase project.
    *   Download the `google-services.json` (for Android) and/or `GoogleService-Info.plist` (for iOS) configuration files and place them in the appropriate directories (`android/app/` and `ios/Runner/`).
    *   Enable necessary Firebase services (Authentication, Firestore/Realtime Database).
5.  **Set up Google Gemini API:**
    *   Obtain an API key from [Google AI Studio](https://aistudio.google.com/app/apikey) or Google Cloud Console.
    *   Configure the API key securely within your application (e.g., using environment variables or a configuration file not checked into version control).
6.  **Set up Google Maps API:**
    *   Obtain an API key from the [Google Cloud Console](https://console.cloud.google.com/apis/library/maps-android-backend.googleapis.com).
    *   Configure the API key in your Android (`AndroidManifest.xml`) and/or iOS (`AppDelegate.swift` or `AppDelegate.m`) configurations.
7.  **Run the app:**
    ```bash
    flutter run
    ```

## Future Development

*   **Pet Customization:** Implement the feature to use earned coins for customizing the virtual pet's appearance.
*   **Full Multilingual Support:** Complete the Malay and Mandarin translations for wider accessibility.
*   **Enhanced AI Interaction:** Explore more sophisticated AI responses and features.
*   **Community Features:** Potentially add opt-in features for peer support or shared experiences.
