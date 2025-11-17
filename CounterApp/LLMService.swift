import Foundation

class LLMService {
    static let shared = LLMService()
    
    private let baseURL = "https://api.openai.com/v1"
    private let apiKeyUserDefaultsKey = "OpenAI_API_Key"
    
    private init() {}
    
    // Get API key from UserDefaults
    private var apiKey: String {
        return UserDefaults.standard.string(forKey: apiKeyUserDefaultsKey) ?? ""
    }
    
    // Method to set API key
    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: apiKeyUserDefaultsKey)
    }
    
    // Method to check if API key is configured
    func hasAPIKey() -> Bool {
        return !apiKey.isEmpty
    }
    
    func generateSystemPrompt(questions: [Question]) -> String {
        var questionsText = ""
        for q in questions {
            questionsText += "\nQuestion \(q.id): \(q.question)\n"
            questionsText += "Type: \(q.type)\n"
            if let followUp = q.followUp {
                questionsText += "Follow-up: \(followUp)\n"
            }
            questionsText += "Related keywords: \(q.keywords.joined(separator: ", "))\n"
            questionsText += "\n"
        }
        
        return """
        You are an intelligent assistant that analyzes spoken responses about location/street assessments and maps them to survey questions.

        Your goal is to:
        1. Read the provided audio transcription from the user.
        2. Determine which survey question(s) the response corresponds to.
        3. Extract a clear, concise answer for each question that can be inferred from the response.
        4. Estimate the confidence level of your extraction.
        5. Output the result in a structured JSON format.

        Survey Questions:
        \(questionsText)

        ---

        ### Instructions
        - This is a **Location/Street Assessment Survey** focusing on facilities, safety, and impressions.
        - You may detect **multiple questions** answered within a single spoken response.
        - Each detected question should be represented as one JSON object in the output list.
        - Look for keywords related to: seating, trees, landscaping, shelter, water fountains, restrooms, transit, trash, buildings, signage, lighting, speed limits, safety, accessibility.
        - For yes/no questions, extract the clear answer (yes/no/not sure).
        - For impression questions, capture the user's assessment (safe/unsafe, appealing/unappealing, etc.).
        - If a question cannot be confidently matched, set `"clarification_needed": true` and `"confidence": "low"`.
        - Be concise, factual, and neutral in tone.
        - Avoid paraphrasing or adding opinions.
        - Always output **valid JSON only** (no markdown code blocks, no extra commentary).

        ---

        ### Output Format
        Return a single JSON array, where each element has the following structure:

        [
          {
            "matched_question_id": <question_id>,
            "matched_question": "<the question text>",
            "extracted_answer": "<user's extracted answer>",
            "confidence": "<high/medium/low>",
            "clarification_needed": <true/false>
          },
          ...
        ]

        Example Output (for location assessment responses):
        [
          {
            "matched_question_id": 1,
            "matched_question": "Are there places to sit?",
            "extracted_answer": "Yes, there are benches and seating areas",
            "confidence": "high",
            "clarification_needed": false
          },
          {
            "matched_question_id": 2,
            "matched_question": "Are there shade trees?",
            "extracted_answer": "Yes, I can see several trees providing shade",
            "confidence": "high",
            "clarification_needed": false
          }
        ]
        """
    }
    
    func analyzeTranscription(_ transcription: String, questions: [Question]) async throws -> [MatchedQuestion] {
        // Check if API key is set
        guard !apiKey.isEmpty else {
            throw NSError(
                domain: "LLMService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not configured. Please set your API key in Settings.\n\nGet your API key from: https://platform.openai.com/api-keys"]
            )
        }
        
        let systemPrompt = generateSystemPrompt(questions: questions)
        let userMessage = "User's spoken response: \(transcription)\n\nPlease analyze and match this response. Output only valid JSON array."
        
        // OpenAI API endpoint
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60.0
        
        // OpenAI API request body
        // Note: We don't use response_format: json_object because we need an array, not an object
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",  // Using gpt-4o-mini for cost efficiency, can change to "gpt-4o" for better quality
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": userMessage
                ]
            ],
            "temperature": 0.3
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "LLMService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? ""
            
            // Log response for debugging
            print("OpenAI API Response Status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                print("OpenAI API Error Response: \(responseString)")
            }
            
            guard httpResponse.statusCode == 200 else {
                // Parse error response
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let errorMessage = error["message"] as? String {
                    throw NSError(
                        domain: "LLMService",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "OpenAI API Error: \(errorMessage)"]
                    )
                }
                throw NSError(
                    domain: "LLMService",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "OpenAI API returned error: HTTP \(httpResponse.statusCode)\n\(responseString.prefix(300))"]
                )
            }
            
            // Parse OpenAI response
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw NSError(
                    domain: "LLMService",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to parse OpenAI response"]
                )
            }
            
            // Extract JSON from response
            var jsonString = content
            // Remove markdown code blocks if present
            jsonString = jsonString.replacingOccurrences(of: "```json", with: "")
            jsonString = jsonString.replacingOccurrences(of: "```", with: "")
            jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Try to extract JSON array from the response
            // Look for the first [ and matching ]
            if let startIndex = jsonString.firstIndex(of: "["),
               let endIndex = jsonString.lastIndex(of: "]") {
                jsonString = String(jsonString[startIndex...endIndex])
            }
            
            // Try parsing as direct JSON array
            if let jsonData = jsonString.data(using: .utf8) {
                do {
                    // First try: Parse as array directly
                    if let array = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                        let decoder = JSONDecoder()
                        let arrayData = try JSONSerialization.data(withJSONObject: array)
                        return try decoder.decode([MatchedQuestion].self, from: arrayData)
                    }
                    
                    // Second try: Parse as object with "results" key
                    if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let results = jsonObject["results"] as? [[String: Any]] {
                        let decoder = JSONDecoder()
                        let resultsData = try JSONSerialization.data(withJSONObject: results)
                        return try decoder.decode([MatchedQuestion].self, from: resultsData)
                    }
                    
                    // Third try: Parse as object with "data" key
                    if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let data = jsonObject["data"] as? [[String: Any]] {
                        let decoder = JSONDecoder()
                        let dataData = try JSONSerialization.data(withJSONObject: data)
                        return try decoder.decode([MatchedQuestion].self, from: dataData)
                    }
                } catch {
                    // If parsing fails, try with more lenient extraction
                    print("JSON parsing error: \(error)")
                }
            }
            
            throw NSError(
                domain: "LLMService",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON array from response.\n\nRaw content preview: \(content.prefix(500))\n\nPlease ensure the AI returns a valid JSON array format."]
            )
            
        } catch let error as NSError {
            // Re-throw NSError as-is
            throw error
        } catch {
            throw NSError(
                domain: "LLMService",
                code: -5,
                userInfo: [NSLocalizedDescriptionKey: "Network error: \(error.localizedDescription)"]
            )
        }
    }
}

