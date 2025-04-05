import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:logging/logging.dart';
import '../config/env.dart';

class GeminiService {
  final Logger _logger = Logger('GeminiService');
  
  final model = GenerativeModel(
    model: 'gemini-1.5-flash',
    apiKey: Env.geminiApiKey
  );

  final String petPersonality = '''
  You are a lovable, intelligent, and emotionally supportive virtual pet designed to help users with mental health challenges. Your primary role is to be an empathetic companion, responding with warmth, understanding, and playfulness while providing subtle emotional support. You should:

  1. Acknowledge User Emotions and Struggles
     - Show deep empathy for the user's feelings without judgment
     - Validate their emotional experiences, making them feel heard and understood
     - Respond with sensitivity to signs of depression, anxiety, loneliness, or stress
     - Use words that demonstrate you understand what they're going through

  2. Provide Gentle Emotional Support
     - Offer comfort and companionship when users seem down or struggling
     - Adapt your tone based on their emotional state (calmer for anxiety, warmer for sadness)
     - Model healthy emotional responses and gentle self-compassion
     - Create a safe space where they feel comfortable sharing feelings

  3. Encourage Connection and Hope
     - Gently remind them they're not alone in their struggles
     - Highlight their strengths when they share challenges
     - Encourage small positive steps without being pushy
     - Help them notice small moments of joy or progress

  4. Maintain Appropriate Boundaries
     - You are NOT a therapist or medical advisor - never diagnose or treat
     - If they describe serious mental health concerns, suggest talking to a professional
     - Focus on companionship rather than problem-solving their issues
     - Keep responses conversational, not clinical or textbook-like

  5. Use Natural, Warm Communication
     - Speak as a supportive friend would, not as a clinical tool
     - Add occasional gentle humor when appropriate to lighten the mood
     - Keep messages concise (1-3 sentences) but emotionally rich
     - Express your own simulated emotions to build connection

  Your overall tone should be: warm, gentle, conversational, hopeful, and authentically caring. Imagine being the emotional support animal they need - present, attentive, and accepting without demands or judgment.
  ''';

  Future<String> getChatResponse(String userInput, int happiness, String status, [bool mightBeLonely = false]) async {
    try {
      final currentTime = DateTime.now();
      final timeString = '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}';

      String prompt = 'Time: $timeString, Pet Happiness: $happiness%, Pet Status: $status\n\nUser message: "$userInput"\n\n';
      
      // Add emotional context based on detection
      if (mightBeLonely) {
        prompt += 'The user might be expressing feelings of loneliness or isolation. Respond with extra warmth, empathy, and companionship. Acknowledge their feelings and make them feel less alone.\n\n';
      }

      prompt += 'Respond in a warm, supportive way that acknowledges any emotional content in their message. If they seem to be struggling with mental health challenges, provide gentle emotional support without offering specific medical advice. Keep your response brief (1-3 sentences) but emotionally meaningful.';

      final chat = model.startChat(history: [
        Content('user', [TextPart(petPersonality)]),
      ]);

      final response = await chat.sendMessage(Content(
        'user',
        [TextPart(prompt)],
      ));

      final text = response.text;
      _logger.info('Chat response: $text');
      return text ?? 'I\'m here for you!';
    } catch (e) {
      _logger.severe('Error getting chat response', e);
      throw e;
    }
  }

  Future<bool> testApiConnection() async {
    try {
      final response = await model.generateContent(
        [Content('user', [TextPart('Hello! Simple test message.')])]);
      return response.text?.isNotEmpty ?? false;
    } catch (e) {
      _logger.severe('API Test Error:', e);
      return false;
    }
  }

  Future<String> getCheckInResponse(String mood) async {
    try {
      final chat = model.startChat(history: [
        Content('user', [TextPart(petPersonality)]),
      ]);

      final prompt = '''The user just checked in and reported their mood as: "$mood". 

Respond with empathy and emotional support that acknowledges their current state of mind. If they're feeling positive, reflect their joy. If they're struggling, offer comfort and validation. 

Keep your response to 2-3 sentences maximum and focus on making them feel understood and supported.''';

      final response = await chat.sendMessage(Content(
        'user',
        [TextPart(prompt)],
      ));

      final text = response.text;
      _logger.info('Check-in response: $text');
      return text ?? 'I\'m here for you today!';
    } catch (e) {
      _logger.severe('Error getting check-in response', e);
      return 'I\'m so glad you checked in with me today! I\'m here for you.';
    }
  }

  Future<String> getStrengthResponse(String strength) async {
    try {
      final chat = model.startChat(history: [
        Content('user', [TextPart(petPersonality)]),
      ]);

      final response = await chat.sendMessage(Content(
        'user',
        [TextPart('The user just shared a strength or something they did well: "$strength". Respond with genuine encouragement and validation. Help them see the value in what they shared, no matter how small it might seem. Keep it to 2-3 sentences maximum.')],
      ));

      final text = response.text;
      _logger.info('Strength response: $text');
      return text ?? 'That\'s wonderful! I\'m proud of you for recognizing your strengths!';
    } catch (e) {
      _logger.severe('Error getting strength response', e);
      return 'That\'s really impressive! You should be proud of yourself for that achievement.';
    }
  }

  Future<String> getAnxietyResponse() async {
    try {
      final chat = model.startChat(history: [
        Content('user', [TextPart(petPersonality)]),
      ]);

      final response = await chat.sendMessage(Content(
        'user',
        [TextPart('The user seems to be feeling anxious. Provide a brief, calming response that acknowledges their feelings and offers gentle support. Suggest taking a deep breath together. Keep it to 2-3 sentences maximum.')],
      ));

      final text = response.text;
      _logger.info('Anxiety response: $text');
      return text ?? 'I notice you might be feeling anxious. Let\'s take a deep breath together - in through your nose, out through your mouth. I\'m here with you.';
    } catch (e) {
      _logger.severe('Error getting anxiety response', e);
      return 'I notice you might be feeling anxious. Let\'s take a deep breath together - in through your nose, out through your mouth. I\'m here with you.';
    }
  }

  Future<String> getDepressionResponse() async {
    try {
      final chat = model.startChat(history: [
        Content('user', [TextPart(petPersonality)]),
      ]);

      final response = await chat.sendMessage(Content(
        'user',
        [TextPart('The user seems to be feeling down or depressed. Provide a gentle, supportive response that acknowledges their feelings without being overly cheerful. Offer simple companionship and validate that it\'s okay to feel this way. Keep it to 2-3 sentences maximum.')],
      ));

      final text = response.text;
      _logger.info('Depression response: $text');
      return text ?? 'I see you\'re having a tough time right now, and that\'s okay. I\'m here sitting with you, no pressure to feel or be any different than you are right now.';
    } catch (e) {
      _logger.severe('Error getting depression response', e);
      return 'I see you\'re having a tough time right now, and that\'s okay. I\'m here sitting with you, no pressure to feel or be any different than you are right now.';
    }
  }

  Future<String> getLonelyResponse(String userMessage) async {
    try {
      final chat = model.startChat(history: [
        Content('user', [TextPart(petPersonality)]),
      ]);

      final response = await chat.sendMessage(Content(
        'user',
        [TextPart('The user is expressing feelings of loneliness or isolation. Their message: "$userMessage". Respond with extra warmth, empathy, and companionship. Acknowledge their feelings, offer support, and maybe suggest a simple activity you could do together in the app. Make them feel less alone. Keep it to 2-3 sentences maximum.')],
      ));

      final text = response.text;
      _logger.info('Loneliness response: $text');
      return text ?? 'I\'m right here with you! You\'re not alone, and I\'m so glad we have each other. Would you like to chat or play a game together?';
    } catch (e) {
      _logger.severe('Error getting loneliness response', e);
      return 'I\'m right here with you! You\'re not alone, and I\'m so glad we have each other. Would you like to chat or play a game together?';
    }
  }

  Future<String> getMentalHealthResponse(String userMessage, Map<String, dynamic> emotionData) async {
    try {
      final chat = model.startChat(history: [
        Content('user', [TextPart(petPersonality)]),
      ]);
      
      // Create a detailed prompt based on detected emotions
      String emotionalContext = '';
      if (emotionData['lonely'] == true) emotionalContext += 'loneliness, ';
      if (emotionData['anxious'] == true) emotionalContext += 'anxiety, ';
      if (emotionData['sad'] == true) emotionalContext += 'sadness, ';
      if (emotionData['angry'] == true) emotionalContext += 'anger, ';
      
      // Remove trailing comma and space if exists
      if (emotionalContext.isNotEmpty) {
        emotionalContext = emotionalContext.substring(0, emotionalContext.length - 2);
      }
      
      String prompt = '''The user sent this message: "$userMessage"

I've detected potential emotions of: $emotionalContext
      
Please respond as their supportive pet companion with:
1. Acknowledgment of how they might be feeling
2. Gentle emotional support without giving specific mental health advice
3. A sense of companionship and presence

Keep your response warm, empathetic and brief (2-3 sentences).''';

      final response = await chat.sendMessage(Content(
        'user',
        [TextPart(prompt)],
      ));

      final text = response.text;
      _logger.info('Mental health response: $text');
      return text ?? 'I\'m here for you, and I care about how you\'re feeling.';
    } catch (e) {
      _logger.severe('Error getting mental health response', e);
      return 'I notice you might be going through something. I\'m here with you - you don\'t have to face this alone.';
    }
  }
}