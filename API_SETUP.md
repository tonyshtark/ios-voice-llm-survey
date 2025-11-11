# OpenAI API Setup Guide

## What You Need to Do

This app uses the **OpenAI API** to analyze transcribed speech. Complete the steps below before running the analysis flow.

### 1. Obtain an OpenAI API Key

1. Visit https://platform.openai.com/api-keys
2. Sign in to your OpenAI account (create one if needed)
3. Click **Create new secret key**
4. Copy the generated key (it is shown only once)

### 2. Configure the API Key in Code

1. Open the Xcode project
2. Locate the `LLMService.swift` file
3. Find the following line:
   ```swift
   private let apiKey = "YOUR_OPENAI_API_KEY_HERE"
   ```
4. Replace the placeholder with your real key:
   ```swift
   private let apiKey = "sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
   ```

### 3. Cost Overview

- The OpenAI API uses a **pay-per-use** model
- The current configuration uses the `gpt-4o-mini` model (lower cost)
- Each call is roughly $0.00015–$0.0003 depending on prompt length
- You can monitor your usage and spending on the OpenAI dashboard

### 4. Optional: Change the Model

If you prefer a more capable (but more expensive) model, adjust the request body in `LLMService.swift`:

```swift
"model": "gpt-4o-mini",  // Change to "gpt-4o" or "gpt-4.1" as needed
```

### 5. Test the Integration

After saving your key, run the app:
1. Record a voice note
2. Tap **LLM Recognition**
3. Seeing the analysis results confirms everything is configured correctly

## Important Notes

- ⚠️ **Do not** commit your API key to version control
- ⚠️ Treat the key as sensitive information and store it securely
- ✅ The app validates the key at runtime and provides clear error messages when the key is missing or invalid

## Using an Alternative LLM Provider

If you want to integrate another LLM (e.g., Anthropic Claude or Google Gemini):
1. Update the API endpoint in `LLMService.swift`
2. Adjust the request format to match the target provider’s API


