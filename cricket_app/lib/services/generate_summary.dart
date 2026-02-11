import 'dart:convert';
import 'package:cricket_app/screens/match_summary.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Generates a dramatic match summary using Groq AI (Llama 3)
/// 
/// Uses Groq's fast inference API with Llama 3 model
/// Free tier with generous rate limits
Future<String> generateDramaticSummary(MatchDetails match) async {
  // Try Groq API first, then fall back to Gemini if available
  final groqApiKey = dotenv.env['GROQ_API_KEY'];
  final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
  
  if (groqApiKey != null && groqApiKey.isNotEmpty) {
    return await _generateWithGroq(match, groqApiKey);
  } else if (geminiApiKey != null && geminiApiKey.isNotEmpty) {
    return await _generateWithGemini(match, geminiApiKey);
  } else {
    return _generateOfflineSummary(match);
  }
}

/// Generate summary using Groq API (Llama 3)
Future<String> _generateWithGroq(MatchDetails match, String apiKey) async {
  const url = 'https://api.groq.com/openai/v1/chat/completions';

  final prompt = '''
🎙️ You are a passionate sports commentator! Generate a **dramatic and emotional match summary** with a spicy, high-energy tone for a cricket match. Here's the match info:

🏟️ **Venue**: ${match.venue}  
📅 **Date**: ${match.date}

🔴 **Team A**: ${match.teamA.name}  
🏏 **Score**: ${match.teamA.runs}/${match.teamA.wickets} in ${match.teamA.overs} overs  
👥 **Players**: ${match.teamA.players.map((p) => p.name).join(', ')}

🔵 **Team B**: ${match.teamB.name}  
🏏 **Score**: ${match.teamB.runs}/${match.teamB.wickets} in ${match.teamB.overs} overs  
👥 **Players**: ${match.teamB.players.map((p) => p.name).join(', ')}

🎯 **Match Result**: ${match.matchSummary}  
🏆 **Victory Margin**: ${match.victoryMargin}

Now write a **MATCH SUMMARY** with:
🔥 Who won  
🎯 Turning points  
💪 Heroic performances  
🎤 Dramatic style commentary like a cricket TV host  
😱 Emotional and powerful language that keeps readers on edge

Start the summary with **"MATCH SUMMARY:"**
Keep it concise but impactful - around 150-200 words.
''';

  try {
    debugPrint('Calling Groq API...');
    
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',  // Fast, high-quality model
        'messages': [
          {
            'role': 'system',
            'content': 'You are an enthusiastic cricket commentator who creates dramatic match summaries.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'temperature': 0.9,
        'max_tokens': 1024,
      }),
    );

    debugPrint('Groq API response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      debugPrint('Groq API error response: ${response.body}');
      // Fall back to offline summary if API fails
      return _generateOfflineSummary(match);
    }

    final body = jsonDecode(response.body);

    // Check for API errors
    if (body.containsKey('error')) {
      final errorMessage = body['error']['message'] ?? 'Unknown error';
      debugPrint('Groq API error: $errorMessage');
      return _generateOfflineSummary(match);
    }

    // Extract the generated text
    final choices = body['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      return _generateOfflineSummary(match);
    }

    final message = choices[0]['message'];
    if (message == null) {
      return _generateOfflineSummary(match);
    }

    final summary = message['content'] as String?;
    
    if (summary == null || summary.isEmpty) {
      return _generateOfflineSummary(match);
    }

    debugPrint('Successfully generated summary with Groq: ${summary.substring(0, 50)}...');
    return summary;
    
  } catch (e, stackTrace) {
    debugPrint('Exception while calling Groq API: $e');
    debugPrint('Stack trace: $stackTrace');
    return _generateOfflineSummary(match);
  }
}

/// Generate summary using Google Gemini API (fallback)
Future<String> _generateWithGemini(MatchDetails match, String apiKey) async {
  const url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  final prompt = '''
🎙️ You are a passionate sports commentator! Generate a **dramatic and emotional match summary** with a spicy, high-energy tone for a cricket match. Here's the match info:

🏟️ **Venue**: ${match.venue}  
📅 **Date**: ${match.date}

🔴 **Team A**: ${match.teamA.name}  
🏏 **Score**: ${match.teamA.runs}/${match.teamA.wickets} in ${match.teamA.overs} overs  
👥 **Players**: ${match.teamA.players.map((p) => p.name).join(', ')}

🔵 **Team B**: ${match.teamB.name}  
🏏 **Score**: ${match.teamB.runs}/${match.teamB.wickets} in ${match.teamB.overs} overs  
👥 **Players**: ${match.teamB.players.map((p) => p.name).join(', ')}

🎯 **Match Result**: ${match.matchSummary}  
🏆 **Victory Margin**: ${match.victoryMargin}

Now write a **MATCH SUMMARY** with:
🔥 Who won  
🎯 Turning points  
💪 Heroic performances  
🎤 Dramatic style commentary like a cricket TV host  
😱 Emotional and powerful language that keeps readers on edge

Start the summary with **"MATCH SUMMARY:"**
Keep it concise but impactful - around 150-200 words.
''';

  try {
    debugPrint('Calling Gemini API...');
    
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'X-goog-api-key': apiKey,
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.9,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 1024,
        }
      }),
    );

    debugPrint('Gemini API response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      debugPrint('Gemini API error response: ${response.body}');
      return _generateOfflineSummary(match);
    }

    final body = jsonDecode(response.body);

    if (body.containsKey('error')) {
      final errorMessage = body['error']['message'] ?? 'Unknown error';
      debugPrint('Gemini API error: $errorMessage');
      return _generateOfflineSummary(match);
    }

    final candidates = body['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      return _generateOfflineSummary(match);
    }

    final content = candidates[0]['content'];
    if (content == null) {
      return _generateOfflineSummary(match);
    }

    final parts = content['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      return _generateOfflineSummary(match);
    }

    final summary = parts[0]['text'] as String?;
    
    if (summary == null || summary.isEmpty) {
      return _generateOfflineSummary(match);
    }

    debugPrint('Successfully generated summary with Gemini: ${summary.substring(0, 50)}...');
    return summary;
    
  } catch (e, stackTrace) {
    debugPrint('Exception while calling Gemini API: $e');
    debugPrint('Stack trace: $stackTrace');
    return _generateOfflineSummary(match);
  }
}

/// Generate an offline summary when API is unavailable
String _generateOfflineSummary(MatchDetails match) {
  final winner = match.teamAWon ? match.teamA.name : match.teamB.name;
  final loser = match.teamAWon ? match.teamB.name : match.teamA.name;
  final winnerScore = match.teamAWon 
      ? '${match.teamA.runs}/${match.teamA.wickets}' 
      : '${match.teamB.runs}/${match.teamB.wickets}';
  final loserScore = match.teamAWon 
      ? '${match.teamB.runs}/${match.teamB.wickets}' 
      : '${match.teamA.runs}/${match.teamA.wickets}';
  
  return '''
**MATCH SUMMARY:**

🏆 **$winner** clinches victory against **$loser** at ${match.venue}!

📊 **Final Scores:**
• $winner: $winnerScore
• $loser: $loserScore

🎯 **Result:** ${match.matchSummary}

🏅 **Victory Margin:** ${match.victoryMargin}

📅 **Date:** ${match.date}

What an incredible match! Both teams gave their all on the field. The winning side showed tremendous skill and determination to secure this memorable victory. A thrilling contest that will be remembered for a long time!

🎙️ Until next time, keep the cricket spirit alive!
''';
}

/// Test function to verify Groq API connectivity
Future<String> testGroqConnection() async {
  final apiKey = dotenv.env['GROQ_API_KEY'];
  
  if (apiKey == null || apiKey.isEmpty) {
    return 'Error: GROQ_API_KEY not found in .env file';
  }

  const url = 'https://api.groq.com/openai/v1/chat/completions';

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {
            'role': 'user',
            'content': 'Say "Hello, Cricket!" in a dramatic way',
          }
        ],
        'max_tokens': 100,
      }),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final text = body['choices']?[0]?['message']?['content'];
      return 'Success! Groq API Response: $text';
    } else {
      return 'Error: Status ${response.statusCode} - ${response.body}';
    }
  } catch (e) {
    return 'Connection failed: $e';
  }
}
