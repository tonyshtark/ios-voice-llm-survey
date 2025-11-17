# Questionnaire LLM iOS App

This Swift-based iOS application assists field researchers in collecting qualitative feedback about specific locations or streets. It records audio, transcribes the speech, and leverages an LLM to match responses to survey questions bundled with the app.

## Feature Highlights

- ✅ **Audio Capture** – Start and stop recording with a single tap
- ✅ **Immediate Playback** – Review the captured audio without leaving the app
- ✅ **Speech-to-Text** – Convert recordings to text using Apple’s Speech framework
- ✅ **LLM Matching** – Send transcripts to the OpenAI API and align answers with questionnaire items
- ✅ **API Key Management** – Configure OpenAI API key through in-app settings (no code modification required)
- ✅ **JSON Export** – Save structured results for reporting or sharing
- ✅ **On-Device Aggregation** – Summarize previously exported survey data into human-readable stats

## Project Structure

```
CounterApp/
├── CounterApp.xcodeproj
├── CounterApp/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── ViewController.swift
│   ├── QuestionnaireModels.swift
│   ├── LLMService.swift
│   ├── Base.lproj/
│   │   ├── Main.storyboard
│   │   └── LaunchScreen.storyboard
│   └── Assets.xcassets/
├── CounterAppTests/
├── CounterAppUITests/
├── questionnaire.json
└── README_iOS.md
```

## Getting Started

1. Open `CounterApp.xcodeproj` in Xcode.
2. Select a target device (simulator or physical device).
3. Confirm that `questionnaire.json` is included in the main bundle.
4. Build and run with **⌘ + R**.
5. **Configure OpenAI API Key**:
   - After launching the app, tap the **Settings** button (⚙️) in the top-right corner of the navigation bar
   - Enter your OpenAI API key in the settings dialog
   - You can get your API key from: https://platform.openai.com/api-keys
   - The API key will be securely stored and persist across app launches
   - ⚠️ **Important**: You must configure the API key before using the LLM Recognition feature

## Key Concepts Covered

- **UIKit Fundamentals** – View controllers, storyboards, and Auto Layout
- **Audio APIs** – Recording and playback with `AVFoundation`
- **Speech Recognition** – Converting audio files to text via `Speech`
- **Networking** – Calling OpenAI’s REST API with `URLSession`
- **JSON Handling** – Decoding and encoding structured survey data
- **File Management** – Writing export files to the app’s documents directory
- **User Preferences** – Storing API keys securely using UserDefaults

## Suggested Extensions

Want to take the project further?

1. Add offline transcription support.
2. Provide localized questionnaires and UI.
3. Visualize aggregated statistics with charts.
4. Sync exports to cloud storage.
5. Add authentication to protect sensitive survey data.

## Requirements

- iOS 17.0 or later
- Xcode 15.0 or later
- Swift 5.0 or later

## License

This project is intended for educational use. Feel free to adapt and extend it for your own research workflows.
