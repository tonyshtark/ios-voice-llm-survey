# iOS Voice Survey App - Setup Instructions

## Feature Overview

This iOS app provides the following capabilities:
1. **Recording** – Tap the record button to start, and tap again to stop
2. **Playback** – Listen to the captured audio directly in the app
3. **Speech Recognition** – Convert recordings to text with Apple’s Speech framework
4. **LLM Analysis** – Send transcriptions to the OpenAI API to match questionnaire items
5. **Export** – Save matched results to JSON for further review
6. **Aggregation** – Summarize exported survey data on-device

## Setup Steps

### 1. Add `questionnaire.json` to the Project

In Xcode:
1. Right-click the `CounterApp` folder
2. Choose **Add Files to "CounterApp"...**
3. Select `CounterApp/CounterApp/questionnaire.json`
4. Make sure **Copy items if needed** and **Add to targets: CounterApp** are checked
5. Click **Add**

### 2. Confirm Swift Files Are Linked

Ensure these files are part of the target:
- `QuestionnaireModels.swift`
- `LLMService.swift`
- `ViewController.swift`

### 3. Configure Permissions

`Info.plist` already includes the required permissions:
- `NSMicrophoneUsageDescription` – microphone access
- `NSSpeechRecognitionUsageDescription` – speech recognition access

### 4. Add Framework Dependencies

Verify the following frameworks are linked under **Build Phases → Link Binary With Libraries**:
- `AVFoundation.framework` (already included)
- `Speech.framework` (add if it is missing)

To add a framework:
1. Select the app target
2. Open the **Build Phases** tab
3. Expand **Link Binary With Libraries**
4. Click the **+** button
5. Search for and add `Speech.framework`

## OpenAI API Details

Set your OpenAI API key in `LLMService.swift` before running the analysis flow. Refer to `API_SETUP.md` for guidance on securing and configuring the key.

If you modify the API integration (e.g., switch providers or models), update the `analyzeTranscription` method in `LLMService.swift` accordingly.

## Usage Flow

1. **Record** – Tap **Start Recording**, speak, then tap **Stop Recording**
2. **Playback** (optional) – Tap **Play Recording**
3. **Analyze** – Tap **LLM Recognition** to run transcription and LLM matching
4. **Export** – Tap **Export JSON** to review or share analysis results
5. **Aggregate** – Tap **Aggregate Results** to summarize previous exports

## Tips

- Grant microphone and speech recognition permissions the first time you launch the app
- Speech recognition requires network connectivity
- LLM analysis depends on network access to the OpenAI API
- Keep `questionnaire.json` bundled with the app to ensure matching works correctly

