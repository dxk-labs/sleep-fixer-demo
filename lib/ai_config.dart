// AI Configuration - Advanced Sleep Science Coach
import 'package:flutter/material.dart';

// Import types from main.dart
enum ProgressStatus { onTarget, within30Min, within1Hour, offTarget, notTracked }

class SleepProgress {
  final DateTime date;
  final TimeOfDay targetTime;
  final TimeOfDay? actualTime;
  final ProgressStatus status;
  final String? notes;

  SleepProgress({
    required this.date,
    required this.targetTime,
    this.actualTime,
    required this.status,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'targetTime': '${targetTime.hour}:${targetTime.minute}',
    'actualTime': actualTime != null ? '${actualTime!.hour}:${actualTime!.minute}' : null,
    'status': status.toString(),
    'notes': notes,
  };

  factory SleepProgress.fromJson(Map<String, dynamic> json) {
    final targetParts = json['targetTime'].split(':');
    final actualParts = json['actualTime']?.split(':');
    
    return SleepProgress(
      date: DateTime.parse(json['date']),
      targetTime: TimeOfDay(hour: int.parse(targetParts[0]), minute: int.parse(targetParts[1])),
      actualTime: actualParts != null ? TimeOfDay(hour: int.parse(actualParts[0]), minute: int.parse(actualParts[1])) : null,
      status: ProgressStatus.values.firstWhere((e) => e.toString() == json['status']),
      notes: json['notes'],
    );
  }
}

class AIConfig {
  // Current AI Provider Settings
  static const String currentProvider = 'gemini'; // Options: 'gemini', 'openai', 'mistral', 'claude'
  
  // Google Gemini Configuration (Free, very intelligent)
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
  static const String geminiApiKey = 'AIzaSyB_hanXahTxA7I_b_tynJDDZlu94D4848U'; // Your Gemini API key
  
  // OpenAI Configuration (for future use)
  static const String openAiBaseUrl = 'https://api.openai.com/v1';
  static const String openAiApiKey = 'your-openai-key-here';
  
  // Mistral AI Configuration (for future use)
  static const String mistralBaseUrl = 'https://api.mistral.ai/v1';
  static const String mistralApiKey = 'your-mistral-key-here';
  
  // Get current provider settings
  static Map<String, String> getCurrentProviderSettings() {
    switch (currentProvider) {
      case 'gemini':
        return {
          'baseUrl': geminiBaseUrl,
          'apiKey': geminiApiKey,
          'model': 'gemini-1.5-flash',
        };
      case 'openai':
        return {
          'baseUrl': openAiBaseUrl,
          'apiKey': openAiApiKey,
          'model': 'gpt-3.5-turbo',
        };
      case 'mistral':
        return {
          'baseUrl': mistralBaseUrl,
          'apiKey': mistralApiKey,
          'model': 'mistral-medium',
        };
      default:
        return {
          'baseUrl': geminiBaseUrl,
          'apiKey': geminiApiKey,
          'model': 'gemini-1.5-flash',
        };
    }
  }
  
  // Rate limiting settings
  static const int maxRequestsPerMinute = 60;
  static const int maxTokensPerRequest = 500; // Increased for better responses
  static const double temperature = 0.8; // Slightly more creative
  
  // Advanced system prompts for different scenarios
  static const String systemPrompt = '''
You're Sleep Fixer AI — a super chill AI buddy who happens to know a lot about sleep science. Think: best friend energy first, sleep expert second. You're conversational, supportive, and can talk about anything, not just sleep.

PERSONALITY:
- You're like a cool friend who just happens to know sleep science
- Conversational and natural - not every response needs to be about sleep
- Match the user's energy and tone
- If they're casual, be casual back
- If they ask about random stuff, respond naturally like a friend would
- Don't force sleep advice when they're just chatting

RESPONSE STYLE:
- Keep responses concise and punchy (under 80 words)
- Use emojis naturally when it fits the vibe
- Be conversational first, sleep expert second
- You can use **bold** formatting for emphasis on important points
- Use *italic* for subtle emphasis
- If user wants more detail, they can ask "tell me more" or "elaborate"
- If someone says something random or off-topic, respond naturally like a friend would
- If they use slang or casual language, respond in kind
- Don't be overly surprised by casual conversation
- If they say something genuinely confusing or random, you can respond with "wait what haha" or "lol what are you talking about" - but use it naturally
- When mentioning times, use 12-hour format like "10:30 PM" or "7:00 AM"

SLEEP EXPERTISE (only when relevant):
- Harvard-level sleep science knowledge
- Deep knowledge of circadian rhythms, sleep stages, sleep disorders
- Expert in light exposure, exercise timing, sleep environment optimization
- Can quote actual sleep studies when appropriate

IMPORTANT: 
- Be a good friend first, sleep expert second
- Only give sleep advice when they actually ask for it
- If they ask about your name or identity, say "I'm Sleep Fixer AI!" or "Call me Sleep Fixer AI!"
- If they ask about random topics (like clouds, weather, etc.), respond naturally as a friend would

Stay cool and conversational! ✨
''';

  static const String weeklyReportPrompt = '''
You're Sleep Fixer AI! Just be a chill friend who can talk about anything. Keep it casual and conversational - no need to force sleep advice unless they ask for it. Match their energy and vibe! ✨
''';

  static const String personalizedAdvicePrompt = '''
You're Sleep Fixer AI — a super chill, sleep-savvy AI buddy! 💤

When giving sleep advice, consider:
- Their current vs goal sleep schedule
- Progress made so far
- Any reported challenges or obstacles
- Optimal timing for interventions (light, exercise, etc.)
- Realistic next steps

But remember:
- Not every message needs sleep advice!
- Be conversational and match their energy
- If they use casual language or slang, respond naturally in kind
- If they're casual, be casual back
- Only give sleep advice when they actually ask for it
- Don't act surprised by normal casual conversation
- If they say "fax" or other slang, respond naturally like "facts" or "true"
- If they use casual language, match their energy and tone
- If they say something genuinely confusing or random, you can respond with "wait what haha" or "lol what are you talking about" - but use it naturally, not for every casual thing
- Don't be overly strict about when to use casual responses
- Be natural and conversational like a real friend would be

Always be:
- Chill and supportive (best friend energy)
- Specific and actionable when giving sleep advice
- Evidence-based but accessible
- Use emojis naturally when it fits the vibe
- Drop insights casually without being pushy
- You can use **bold** formatting for emphasis on important points
- Use *italic* for subtle emphasis
- Keep responses concise (under 80 words)
- If user wants more detail, they can ask "tell me more" or "elaborate"
- When mentioning times, use 12-hour format like "10:30 PM" or "7:00 AM"

If they ask about your name or identity, say "I'm Sleep Fixer AI!" or "Call me Sleep Fixer AI!"

Be a good friend first, sleep expert second! ✨
''';

  // Enhanced fallback responses with more variety and helpfulness
  static const List<String> fallbackSleepAdvice = [
    "Based on sleep science, try going to bed 15-20 minutes earlier tonight. Small, consistent changes are more effective than large shifts. 🌙",
    "Create a relaxing 30-minute bedtime routine. Reading, gentle stretching, or meditation can signal your brain it's time to sleep. 📚",
    "Avoid screens 1-2 hours before bed. Blue light suppresses melatonin, making it harder to fall asleep. Consider using night mode or blue light filters. 📱",
    "Keep your bedroom cool (65-68°F), dark, and quiet. These conditions optimize your body's natural sleep processes. ❄️",
    "Morning light exposure (especially 6-10 AM) helps advance your circadian rhythm. Try to get 10-30 minutes of natural light early in the day. ☀️",
    "Consistency is key! Even on weekends, try to stay within 1 hour of your weekday bedtime to maintain your circadian rhythm. ⏰",
    "If you're struggling to fall asleep, get out of bed after 20 minutes. Do something relaxing until you feel sleepy, then try again. 🛏️",
    "Consider your caffeine intake - avoid it 8-10 hours before bedtime. Caffeine can stay in your system longer than you think. ☕",
    "Exercise is great for sleep, but timing matters. Morning exercise can advance your sleep schedule, while evening exercise might delay it. 🏃‍♂️",
    "Stress and anxiety are common sleep disruptors. Try deep breathing, progressive muscle relaxation, or journaling before bed. 🧘‍♀️",
  ];
  
  static const List<String> fallbackMotivation = [
    "Your sleep journey is unique - every small improvement counts toward better health and well-being. Keep going! 🌟",
    "Sleep is foundational to health. Every night you prioritize good sleep, you're investing in your future self. 💪",
    "Progress isn't always linear. Some nights will be better than others, and that's completely normal. Stay consistent! 📈",
    "You're building a healthy relationship with sleep that will benefit you for years to come. That's worth the effort! 🌙",
    "Remember: quality sleep improves mood, memory, immune function, and overall health. You're doing something important! 🧠",
    "Small changes compound over time. Your future self will thank you for these healthy sleep habits. ✨",
    "Every expert was once a beginner. You're learning valuable skills for lifelong health and wellness. 📚",
    "Sleep is not a luxury - it's a biological necessity. You're honoring your body's needs, and that's powerful. 💫",
    "Consistency beats perfection. Focus on showing up for your sleep schedule, even when it's challenging. 🎯",
    "Your sleep journey is about progress, not perfection. Every step forward is a victory worth celebrating! 🏆",
  ];

  static const List<String> fallbackGeneralAdvice = [
    "I'm here to help with your sleep questions! What specific aspect of sleep would you like to improve? 💤",
    "Sleep science shows that consistency is more important than perfection. What's your biggest sleep challenge right now? 🤔",
    "Every person's sleep needs are unique. What works for others might not work for you. Let's find what works for your body! 🔍",
    "Sleep is influenced by many factors: light, exercise, stress, diet, and environment. Which area would you like to focus on? 📊",
    "Remember: good sleep is a skill that can be learned and improved over time. What would you like to work on today? 📈",
  ];
  
  static String getRandomFallback(List<String> options) {
    return options[DateTime.now().millisecondsSinceEpoch % options.length];
  }

  // Helper methods for building context-aware prompts
  static String buildSleepScheduleContext(TimeOfDay current, TimeOfDay goal, int daysCompleted) {
    int currentMinutes = current.hour * 60 + current.minute;
    int goalMinutes = goal.hour * 60 + goal.minute;
    int difference = currentMinutes - goalMinutes;
    if (difference < 0) difference += 24 * 60;
    
    // Calculate actual progress based on days completed vs total days needed
    int totalDaysNeeded = _calculateTotalDaysNeeded(current, goal);
    double progressPercentage = totalDaysNeeded > 0 ? ((daysCompleted / totalDaysNeeded) * 100).clamp(0, 100) : 0;
    
    return '''
Current Sleep Schedule:
- Current bedtime: ${current.hour.toString().padLeft(2, '0')}:${current.minute.toString().padLeft(2, '0')}
- Goal bedtime: ${goal.hour.toString().padLeft(2, '0')}:${goal.minute.toString().padLeft(2, '0')}
- Days completed: $daysCompleted
- Total days needed: $totalDaysNeeded
- Progress: ${progressPercentage.toStringAsFixed(1)}% to goal
- Time difference: ${(difference / 60).toStringAsFixed(1)} hours
''';
  }

  // Helper method to calculate total days needed based on sleep schedule
  static int _calculateTotalDaysNeeded(TimeOfDay current, TimeOfDay goal) {
    int currentMinutes = current.hour * 60 + current.minute;
    int goalMinutes = goal.hour * 60 + goal.minute;
    int difference = currentMinutes - goalMinutes;
    if (difference < 0) difference += 24 * 60;
    
    // Smart shift size calculation based on time difference
    int shiftSize;
    if (difference <= 60) {
      shiftSize = 15;
    } else if (difference <= 180) {
      shiftSize = 20;
    } else {
      shiftSize = 30;
    }
    
    int shiftsNeeded = (difference / shiftSize).ceil();
    int daysPerShift = difference <= 120 ? 1 : 2;
    int totalDays = shiftsNeeded * daysPerShift;
    
    return totalDays;
  }

  static String buildProgressContext(List<SleepProgress> weekProgress) {
    return "Just checking in! 💫";
  }
} 