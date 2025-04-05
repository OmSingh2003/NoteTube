# 📒 NoteTube

NoteTube is a Flutter application that allows users to convert **YouTube videos** or **audio files** into **transcribed notes** using the **Lemonfox Whisper API**, with the ability to **download transcripts as PDF**.

---

## ✨ Features

- 🎥 Paste YouTube video links for transcription
- 🎧 Upload audio files for accurate transcription
- 🤖 Powered by Whisper v3 (via Lemonfox)
- 📄 Download transcriptions as PDF
- 🌐 Supports over 100 languages

---

## 📸 Screenshots

*(Add screenshots here if available)*

---

## 🛠️ Getting Started

### 1. Clone the repo

```bash
git clone https://github.com/yourusername/notetube.git
cd notetube

2. Install dependencies
flutter pub get
3. Set up the API Key
Replace "YOUR_API_KEY" in lib/services/whisper_service.dart with your Lemonfox Whisper API key:

static const String _apiKey = 'YOUR_API_KEY'; // <- Replace this
4. Run the app
flutter run
📦 Dependencies

http
file_picker
pdf
path_provider
📁 Project Structure

lib/
├── main.dart
├── services/
│   └── whisper_service.dart
└── utils/
    └── pdf_generator.dart
🧠 Powered By

Lemonfox Whisper API
Whisper Large-v3 model from OpenAI
🔒 License

This project is licensed under the MIT License.

