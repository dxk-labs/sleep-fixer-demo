# Sleep Fixer AI Setup Guide

## 🚀 Quick Start

1. **API Key Already Configured** ✅
   - Your Gemini API key is already set up in `lib/ai_config.dart`
   - No additional setup needed!

2. **Test the AI**
   - Run the app: `flutter run`
   - Create a sleep plan
   - Tap "SleepGPT" in the bottom navigation to chat with the AI

## 🔧 Configuration Options

### Current AI Provider: Google Gemini 1.5 Flash
- **Base URL**: `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent`
- **Model**: `gemini-1.5-flash` (Latest and most capable)
- **Rate Limit**: 15 requests/minute (free tier)
- **Cost**: Free
- **Style**: Gen-Z sleep coach with emojis and supportive vibes

### Easy Provider Switching

To switch to a different AI provider, edit `lib/ai_config.dart`:

```dart
// Change this line to switch providers
static const String currentProvider = 'openai'; // or 'mistral', 'claude'
```

### Available Providers

1. **Google Gemini** (Current)
   - Completely free
   - Latest AI model (Gemini 1.5 Flash)
   - 15 requests/minute free
   - Very intelligent and conversational
   - Gen-Z sleep coach personality
   - Google's most advanced AI

2. **OpenAI** (Future)
   - Most popular
   - Pay-per-use
   - Best quality

3. **Mistral AI** (Future)
   - European company
   - GDPR compliant
   - Good performance

## 🛠️ Features

### AI Chat
- Personalized sleep advice
- Science-based recommendations
- Context-aware responses

### Smart Notifications
- Weekly progress summaries
- Motivational messages
- Personalized tips

### Fallback System
- Works offline with pre-written responses
- Graceful error handling
- Always provides helpful advice

## 📱 Usage

### For Users
1. Create a sleep plan
2. Tap "Sleep Fixer AI" button
3. Ask questions about sleep
4. Get personalized advice

### For Developers
1. AI responses are cached locally
2. Fallback responses ensure app always works
3. Easy to add new AI providers
4. Rate limiting prevents API abuse

## 🔒 Privacy & Security

- API keys are stored locally
- No user data sent to AI providers
- Fallback responses work offline
- Rate limiting protects against abuse

## 🚀 Future Enhancements

- [ ] Add more AI providers
- [ ] Implement conversation history
- [ ] Add voice chat capability
- [ ] Personalized sleep insights
- [ ] Integration with sleep trackers

## 🐛 Troubleshooting

### AI Not Responding?
1. Check your internet connection
2. Verify your API key is correct
3. Check if you've hit rate limits
4. App will show fallback responses

### Want to Test Without API?
The app includes fallback responses that work offline. Just run the app without configuring an API key.

## 📞 Support

If you need help:
1. Check the error messages in the app
2. Verify your API key is working
3. Try the fallback responses first
4. Contact the development team 