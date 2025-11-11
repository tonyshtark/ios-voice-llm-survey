import UIKit
import AVFoundation
import Speech

class ViewController: UIViewController, AVAudioPlayerDelegate {
    
    // MARK: - Properties
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var llmButton: UIButton!
    @IBOutlet weak var exportButton: UIButton!
    @IBOutlet weak var aggregateButton: UIButton!
    
    // Recording state
    private var isRecording = false
    private var recordedData: String?
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingURL: URL?
    
    // Questionnaire and analysis
    private var questionnaireData: QuestionnaireData?
    private var transcription: String?
    private var matchedQuestions: [MatchedQuestion] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        loadQuestionnaire()
        requestSpeechPermission()
        setupUI()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Set title
        title = "Voice Recognition"
        
        // Request microphone permission
        requestMicrophonePermission()
        
        // Setup status label
        statusLabel.text = "Ready"
        statusLabel.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        statusLabel.textAlignment = .center
        statusLabel.textColor = .systemGray
        statusLabel.numberOfLines = 0
        
        // Setup record button
        setupButton(recordButton, title: "Start Recording", backgroundColor: .systemRed)
        
        // Setup play button
        setupButton(playButton, title: "Play Recording", backgroundColor: .systemPurple)
        
        // Setup LLM button
        setupButton(llmButton, title: "LLM Recognition", backgroundColor: .systemBlue)
        
        // Setup export button
        setupButton(exportButton, title: "Export JSON", backgroundColor: .systemGreen)
        
        // Setup aggregate button
        setupButton(aggregateButton, title: "Aggregate Results", backgroundColor: .systemTeal)
        
        // Initial state: play, LLM and export buttons disabled
        playButton.isEnabled = false
        llmButton.isEnabled = false
        exportButton.isEnabled = false
        playButton.alpha = 0.5
        llmButton.alpha = 0.5
        exportButton.alpha = 0.5
    }
    
    private func setupButton(_ button: UIButton, title: String, backgroundColor: UIColor) {
        button.setTitle(title, for: .normal)
        button.backgroundColor = backgroundColor
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
    }
    
    // MARK: - Button Actions
    @IBAction func recordButtonTapped(_ sender: UIButton) {
        isRecording.toggle()
        
        if isRecording {
            // Start recording
            startRecording()
        } else {
            // Stop recording
            stopRecording()
        }
        
        animateButton(sender)
    }
    
    @IBAction func playButtonTapped(_ sender: UIButton) {
        guard let url = recordingURL else {
            showMessage("No recording to play")
            return
        }
        
        // Check if already playing
        if let player = audioPlayer, player.isPlaying {
            // Stop playing
            player.stop()
            audioPlayer = nil
            
            playButton.setTitle("Play Recording", for: .normal)
            playButton.backgroundColor = .systemPurple
            statusLabel.text = "Playback stopped"
            statusLabel.textColor = .systemGray
        } else {
            // Start playing
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.delegate = self
                audioPlayer?.play()
                
                statusLabel.text = "Playing recording..."
                statusLabel.textColor = .systemPurple
                
                playButton.setTitle("Stop Playback", for: .normal)
                playButton.backgroundColor = .systemRed
                
            } catch {
                showMessage("Playback failed: \(error.localizedDescription)")
            }
        }
        
        animateButton(sender)
    }
    
    @IBAction func llmButtonTapped(_ sender: UIButton) {
        guard let recordingURL = recordingURL else {
            showMessage("No recording available. Please record first.")
            return
        }
        
        // Disable button to prevent duplicate clicks
        llmButton.isEnabled = false
        llmButton.alpha = 0.5
        statusLabel.text = "Transcribing audio...\nPlease wait"
        statusLabel.textColor = .systemBlue
        
        // Step 1: Transcribe audio
        transcribeAudio(url: recordingURL) { [weak self] transcription in
            guard let self = self else { return }
            
            guard let transcription = transcription, !transcription.isEmpty else {
                DispatchQueue.main.async {
                    self.statusLabel.text = "Transcription failed"
                    self.statusLabel.textColor = .systemRed
                    self.llmButton.isEnabled = true
                    self.llmButton.alpha = 1.0
                    self.showMessage("Failed to transcribe audio. Please try again.")
                }
                return
            }
            
            self.transcription = transcription
            
            DispatchQueue.main.async {
                self.statusLabel.text = "Analyzing with LLM...\nPlease wait"
                self.statusLabel.textColor = .systemBlue
            }
            
            // Step 2: Analyze with POE API
            guard let questions = self.questionnaireData?.questionnaire.questions else {
                DispatchQueue.main.async {
                    self.statusLabel.text = "Questionnaire not loaded"
                    self.statusLabel.textColor = .systemRed
                    self.llmButton.isEnabled = true
                    self.llmButton.alpha = 1.0
                }
                return
            }
            
            Task {
                do {
                    let matchedQuestions = try await LLMService.shared.analyzeTranscription(transcription, questions: questions)
                    
                    DispatchQueue.main.async {
                        self.matchedQuestions = matchedQuestions
                        self.displayResults(transcription: transcription, matchedQuestions: matchedQuestions)
                        
                        // Update recorded data
                        let resultSummary = matchedQuestions.map { "Q\($0.matchedQuestionId): \($0.extractedAnswer)" }.joined(separator: "\n")
                        self.recordedData = "Transcription: \(transcription)\n\nMatched Questions:\n\(resultSummary)"
                        
                        self.statusLabel.text = "Analysis complete!\n\(matchedQuestions.count) question(s) matched"
                        self.statusLabel.textColor = .systemGreen
                        
                        self.llmButton.isEnabled = true
                        self.llmButton.alpha = 1.0
                    }
                } catch {
                    DispatchQueue.main.async {
                        let errorMessage = error.localizedDescription
                        self.statusLabel.text = "LLM analysis failed\nCheck error details"
                        self.statusLabel.textColor = .systemRed
                        self.llmButton.isEnabled = true
                        self.llmButton.alpha = 1.0
                        
                        // Show detailed error in alert
                        let alert = UIAlertController(
                            title: "API Call Failed",
                            message: errorMessage,
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                        
                        // Also log to console
                        print("LLM API Error: \(errorMessage)")
                    }
                }
            }
        }
        
        animateButton(sender)
    }
    
    @IBAction func exportButtonTapped(_ sender: UIButton) {
        guard let transcription = transcription, !matchedQuestions.isEmpty else {
            showMessage("No analysis data to export")
            return
        }
        
        // Create comprehensive JSON data
        let timestamp = Date().timeIntervalSince1970
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestampString = dateFormatter.string(from: Date())
        
        var exportData: [String: Any] = [
            "export_info": [
                "export_time": timestampString,
                "total_responses": 1,
                "questionnaire_title": questionnaireData?.questionnaire.title ?? "Unknown"
            ],
            "timestamp": timestamp,
            "transcription": transcription,
            "matched_questions": matchedQuestions.map { matched in
                [
                    "matched_question_id": matched.matchedQuestionId,
                    "matched_question": matched.matchedQuestion,
                    "extracted_answer": matched.extractedAnswer,
                    "confidence": matched.confidence,
                    "clarification_needed": matched.clarificationNeeded
                ]
            }
        ]
        
        // Add questionnaire if available
        if let questionnaire = questionnaireData {
            exportData["questionnaire"] = [
                "title": questionnaire.questionnaire.title,
                "description": questionnaire.questionnaire.description
            ]
        }
        
        // Convert to JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted) else {
            showMessage("JSON conversion failed")
            return
        }
        
        // Save to app-specific directory
        let fileName = "survey_results_\(Date().timeIntervalSince1970).json"
        
        guard let exportsDirectory = try? ensureExportsDirectory() else {
            statusLabel.text = "Failed to create directory"
            statusLabel.textColor = .systemRed
            showMessage("Unable to create or access the export directory")
            animateButton(sender)
            return
        }
        
        let fileURL = exportsDirectory.appendingPathComponent(fileName)
        
        do {
            try jsonData.write(to: fileURL)
            
            // Show export success
            statusLabel.text = "JSON exported successfully!\nSaved to App Folder"
            statusLabel.textColor = .systemGreen
            
            // Show success message with file location
            let alert = UIAlertController(
                title: "Export Successful",
                message: "File saved to:\n\(fileName)\n\nLocation: App Folder/SurveyExports\n\nYou can access it via Files app or iTunes File Sharing.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "View JSON", style: .default) { _ in
                // Show JSON content in a scrollable view
                self.showJSONContent(String(data: jsonData, encoding: .utf8) ?? "")
            })
            alert.addAction(UIAlertAction(title: "Share", style: .default) { _ in
                // Show share sheet
                self.shareFile(url: fileURL)
            })
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
            
            // Also print file path for debugging
            print("File saved to: \(fileURL.path)")
            
        } catch {
            statusLabel.text = "Export failed"
            statusLabel.textColor = .systemRed
            showMessage("Failed to save file: \(error.localizedDescription)")
        }
        
        animateButton(sender)
    }
    
    @IBAction func aggregateButtonTapped(_ sender: UIButton) {
        animateButton(sender)
        
        statusLabel.text = "Aggregating historical responses..."
        statusLabel.textColor = .systemBlue
        aggregateButton.isEnabled = false
        aggregateButton.alpha = 0.5
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let exportsDirectory = try self.ensureExportsDirectory()
                let fileManager = FileManager.default
                let fileURLs = try fileManager.contentsOfDirectory(at: exportsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]).filter { $0.pathExtension.lowercased() == "json" }
                
                if fileURLs.isEmpty {
                    DispatchQueue.main.async {
                        self.statusLabel.text = "No historical data available for aggregation"
                        self.statusLabel.textColor = .systemOrange
                        self.showMessage("No export files available for aggregation")
                        self.aggregateButton.isEnabled = true
                        self.aggregateButton.alpha = 1.0
                    }
                    return
                }
                
                var statistics: [Int: [String: Int]] = [:]
                var answerDisplayNames: [Int: [String: String]] = [:]
                var questionTexts: [Int: String] = [:]
                
                if let questions = self.questionnaireData?.questionnaire.questions {
                    for question in questions {
                        questionTexts[question.id] = question.question
                    }
                }
                
                let decoder = JSONDecoder()
                var processedFiles = 0
                
                for fileURL in fileURLs {
                    do {
                        let data = try Data(contentsOf: fileURL)
                        let exportEntry = try decoder.decode(ExportedSurvey.self, from: data)
                        processedFiles += 1
                        
                        for item in exportEntry.matchedQuestions {
                            guard let answer = item.extractedAnswer?.trimmingCharacters(in: .whitespacesAndNewlines), !answer.isEmpty else {
                                continue
                            }
                            
                            let normalizedAnswer = answer.lowercased()
                            statistics[item.matchedQuestionId, default: [:]][normalizedAnswer, default: 0] += 1
                            
                            if answerDisplayNames[item.matchedQuestionId] == nil {
                                answerDisplayNames[item.matchedQuestionId] = [:]
                            }
                            
                            if answerDisplayNames[item.matchedQuestionId]?[normalizedAnswer] == nil {
                                answerDisplayNames[item.matchedQuestionId]?[normalizedAnswer] = answer
                            }
                            
                            if questionTexts[item.matchedQuestionId] == nil {
                                questionTexts[item.matchedQuestionId] = item.matchedQuestion
                            }
                        }
                    } catch {
                        print("Failed to process file \(fileURL.lastPathComponent): \(error)")
                    }
                }
                
                let nonEmptyStats = statistics.filter { !$0.value.isEmpty }
                
                if nonEmptyStats.isEmpty {
                    DispatchQueue.main.async {
                        self.statusLabel.text = "No valid response data found"
                        self.statusLabel.textColor = .systemOrange
                        self.showMessage("No valid responses found in any export files")
                        self.aggregateButton.isEnabled = true
                        self.aggregateButton.alpha = 1.0
                    }
                    return
                }
                
                var summary = "Analyzed \(processedFiles) export file(s).\n\n"
                let sortedQuestionIds = nonEmptyStats.keys.sorted()
                
                for questionId in sortedQuestionIds {
                    let questionTitle = questionTexts[questionId] ?? "Question \(questionId)"
                    summary += "Question \(questionId): \(questionTitle)\n"
                    
                    let answerCounts = nonEmptyStats[questionId] ?? [:]
                    let sortedAnswers = answerCounts.sorted { lhs, rhs in
                        if lhs.value == rhs.value {
                            return lhs.key < rhs.key
                        }
                        return lhs.value > rhs.value
                    }
                    
                    for (answerKey, count) in sortedAnswers {
                        let displayText = answerDisplayNames[questionId]?[answerKey] ?? answerKey
                        summary += "  - \(displayText): \(count) responses\n"
                    }
                    
                    summary += "\n"
                }
                
                DispatchQueue.main.async {
                    self.statusLabel.text = "Aggregation complete. Processed \(processedFiles) record(s)"
                    self.statusLabel.textColor = .systemGreen
                    self.showScrollableContent(title: "Aggregation Results", content: summary)
                    self.aggregateButton.isEnabled = true
                    self.aggregateButton.alpha = 1.0
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusLabel.text = "Aggregation failed"
                    self.statusLabel.textColor = .systemRed
                    self.showMessage("Unable to access export directory: \(error.localizedDescription)")
                    self.aggregateButton.isEnabled = true
                    self.aggregateButton.alpha = 1.0
                }
            }
        }
    }
    
    // MARK: - Questionnaire Loading
    private func loadQuestionnaire() {
        guard let url = Bundle.main.url(forResource: "questionnaire", withExtension: "json") else {
            print("Error: questionnaire.json not found in bundle")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            questionnaireData = try decoder.decode(QuestionnaireData.self, from: data)
            print("Questionnaire loaded successfully: \(questionnaireData?.questionnaire.title ?? "Unknown")")
        } catch {
            print("Error loading questionnaire: \(error)")
            showMessage("Failed to load questionnaire: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Permission Requests
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if !granted {
                    self.showMessage("Microphone permission is required to record")
                }
            }
        }
    }
    
    private func requestSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    self.showMessage("Speech recognition permission is required for transcription")
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            showMessage("Audio session setup failed: \(error.localizedDescription)")
            return
        }
        
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documentsPath.appendingPathComponent(fileName)
        recordingURL = url
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            
            recordButton.setTitle("Stop Recording", for: .normal)
            recordButton.backgroundColor = .systemOrange
            statusLabel.text = "Recording...\nSpeak into microphone"
            statusLabel.textColor = .systemRed
        } catch {
            showMessage("Recording failed to start: \(error.localizedDescription)")
        }
    }
    
    private func stopRecording() {
        audioRecorder?.stop()
        
        recordButton.setTitle("Start Recording", for: .normal)
        recordButton.backgroundColor = .systemRed
        statusLabel.text = "Recording stopped\nYou can play, recognize, or export"
        statusLabel.textColor = .systemGray
        
        // Enable buttons
        playButton.isEnabled = true
        llmButton.isEnabled = true
        exportButton.isEnabled = true
        playButton.alpha = 1.0
        llmButton.alpha = 1.0
        exportButton.alpha = 1.0
        
        recordedData = "Recording data - Timestamp: \(Date().timeIntervalSince1970)"
    }
    
    // MARK: - Speech Recognition
    private func transcribeAudio(url: URL, completion: @escaping (String?) -> Void) {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            completion(nil)
            return
        }
        
        if !recognizer.isAvailable {
            completion(nil)
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        
        recognizer.recognitionTask(with: request) { result, error in
            if let error = error {
                print("Speech recognition error: \(error)")
                completion(nil)
                return
            }
            
            if let result = result, result.isFinal {
                completion(result.bestTranscription.formattedString)
            }
        }
    }
    
    // MARK: - Results Display
    private func displayResults(transcription: String, matchedQuestions: [MatchedQuestion]) {
        var resultText = "Transcription:\n\(transcription)\n\n"
        resultText += "Matched Questions:\n"
        
        for matched in matchedQuestions {
            resultText += "\nQuestion \(matched.matchedQuestionId): \(matched.matchedQuestion)\n"
            resultText += "Answer: \(matched.extractedAnswer)\n"
            resultText += "Confidence: \(matched.confidence)\n"
            if matched.clarificationNeeded {
                resultText += "⚠️ Clarification needed\n"
            }
        }
        
        // Show results in alert
        let alert = UIAlertController(title: "Analysis Results", message: resultText, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.playButton.setTitle("Play Recording", for: .normal)
            self.playButton.backgroundColor = .systemPurple
            self.statusLabel.text = "Playback complete"
            self.statusLabel.textColor = .systemGray
        }
    }
    
    // MARK: - Helper Methods
    private func animateButton(_ button: UIButton) {
        UIView.animate(withDuration: 0.1, animations: {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                button.transform = CGAffineTransform.identity
            }
        }
    }
    
    private func showMessage(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        
        // Auto dismiss after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }
    
    private func showJSONContent(_ jsonString: String) {
        showScrollableContent(title: "Exported JSON", content: jsonString)
    }
    
    private func shareFile(url: URL) {
        let activityViewController = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        // For iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(activityViewController, animated: true)
    }
    
    private func jsonToPrettyString(_ json: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
    
    private func ensureExportsDirectory() throws -> URL {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportsURL = documentsURL.appendingPathComponent("SurveyExports", isDirectory: true)
        
        if !fileManager.fileExists(atPath: exportsURL.path) {
            try fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        return exportsURL
    }
    
    private func showScrollableContent(title: String, content: String) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        
        let textView = UITextView()
        textView.text = content
        textView.font = UIFont.systemFont(ofSize: 12)
        textView.isEditable = false
        textView.backgroundColor = .systemBackground
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        alert.view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 60),
            textView.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor, constant: 15),
            textView.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor, constant: -15),
            textView.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -60),
            textView.heightAnchor.constraint(equalToConstant: 300)
        ])
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

private struct ExportedSurvey: Decodable {
    let matchedQuestions: [ExportedMatchedQuestion]
    
    enum CodingKeys: String, CodingKey {
        case matchedQuestions = "matched_questions"
    }
}

private struct ExportedMatchedQuestion: Decodable {
    let matchedQuestionId: Int
    let matchedQuestion: String
    let extractedAnswer: String?
    
    enum CodingKeys: String, CodingKey {
        case matchedQuestionId = "matched_question_id"
        case matchedQuestion = "matched_question"
        case extractedAnswer = "extracted_answer"
    }
}