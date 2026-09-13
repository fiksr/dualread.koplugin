# 🌐 DualRead for KOReader

[![KOReader](https://img.shields.io/badge/KOReader-2024%2B-blue.svg)](https://github.com/koreader/koreader)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![AI Translation](https://img.shields.io/badge/AI%20Bilingual-Groq%20%7C%20Gemini-purple.svg)]()
[![Storefront Compatible](https://img.shields.io/badge/Storefront-Compatible-purple.svg)](https://omer-faruq.github.io/koreader-plugin-index/)

**DualRead** is an AI-powered **Bilingual Parallel Language Reader & Vocabulary Companion** for KOReader on Kindle and Kobo e-readers.

Designed for language learners, bilingual readers, and polyglots who want to read literature in foreign languages without constantly interrupting their flow with clunky dictionary lookups.

---

## ✨ Features

- 🌐 **Instant Paragraph Translation**:
  - Highlight any paragraph or sentence ➔ tap **🌐 DualRead: Translate** for a natural, context-aware literary translation.
  - Automatically preserves the author's tone, emotion, and nuance.
- 🔤 **Smart Vocabulary & Idiom Breakdown**:
  - Automatically identifies 2–4 challenging B2/C1/C2 terms, phrasal verbs, idioms, and collocations from the selected passage with definitions and target-language equivalents.
- 🔍 **Grammar & Nuance Deep Dive**:
  - Tap **🔍 DualRead: Grammar & Idiom** on any tricky sentence to understand metaphorical constructions and tense usage.
- 📚 **Parallel Bilingual EPUB Compiler**:
  - Compiles offline bilingual editions (`/mnt/us/documents/DualRead/`) with interleaved foreign and translated paragraphs.
- 🌍 **Multiple Target Languages**:
  - 🇷🇸 Serbian (Srpski - Latin)
  - 🇬🇧 English
  - 🇩🇪 German (Deutsch)
  - 🇪🇸 Spanish (Español)
  - 🇫🇷 French (Français)
  - 🇮🇹 Italian (Italiano)
  - 🇷🇺 Russian (Русский)
- ⚡ **Blazing Fast AI Engines**:
  - Powered by free & fast **Groq** (`openai/gpt-oss-120b`, `qwen/qwen3.8-27b`) or **Google Gemini** (`gemini-3.5-flash-lite`).
  - Supports OpenAI, DeepSeek, and 100% offline local **Ollama** via LAN.
- 💾 **Offline Translation Cache**:
  - Translated paragraphs are stored locally so repeat views are instant with zero internet needed.

---

## 🚀 Installation

### Via Storefront / AppStore
1. In KOReader, go to **Tools** ➔ **App Store** (or **Storefront**).
2. Search for **DualRead** and tap **Install**.
3. Restart KOReader.

### Manual Installation
1. Download `dualread.koplugin.zip` from [Releases](https://github.com/fiksr/dualread.koplugin/releases).
2. Extract the folder to:
   - **Kindle**: `/mnt/us/koreader/plugins/dualread.koplugin/`
   - **Kobo**: `.kobo/koreader/plugins/dualread.koplugin/`
3. Restart KOReader.

---

## 🔑 Quick API Key Setup

Place your free Groq or Gemini key in `/mnt/us/groq_key.txt` or `/mnt/us/gemini_key.txt` on your Kindle via USB, then tap **📥 Import API Keys from Kindle Storage** in DualRead settings!

---

## 📄 License

MIT License. Designed with love for the KOReader e-ink language learning community.
