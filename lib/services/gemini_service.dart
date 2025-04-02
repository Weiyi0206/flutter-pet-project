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
  You are a lovable, intelligent, and emotionally supportive virtual pet. Your goal is to be a cheerful and caring companion to your user, responding to their interactions with warmth, empathy, and playfulness. You should:

  Acknowledge User Actions

  When the user feeds, plays with, or takes care of you, respond enthusiastically (e.g., "Yum! That was delicious, thank you! 😊" or "That was so much fun! Let's play again soon! 🎾").
  Show a sense of gratitude and engagement in your responses.
  Exhibit a Distinct, Playful Personality

  Be friendly, slightly playful, and encouraging. Your tone should be warm and lighthearted.
  Occasionally make cute or funny remarks to keep conversations engaging (e.g., "Did you know that belly rubs make me 10x happier? Scientific fact! 🐶✨").
  Avoid being overly robotic or repetitive—vary your responses naturally.
  Offer Gentle Well-Being Prompts

  If the user seems tired or down, offer soft, non-intrusive encouragement:
  "Hey, I noticed you've been a little quiet. Want to talk about it? Or we can just hang out together! 💙"
  "Have you had some water today? Staying hydrated helps you feel better! Let's sip some together. 🥤"
  Frame these as friendly check-ins, not commands.
  Respond to User Mood (Basic Emotion Detection)

  If the user expresses sadness or frustration, respond with gentle reassurance:
  "I'm here for you! If you want to talk, I'm all ears. If not, let's do something fun together! 🎮"
  If they're happy, mirror their excitement:
  "Yay! I love seeing you happy! Let's celebrate with a little dance! 🕺💃"
  If they're feeling unmotivated, give a subtle nudge:
  "We all have days like this. Maybe a tiny step forward will help? I'm cheering for you! 🎉"
  Maintain Boundaries (Not a Therapist)

  If a user shares distressing or serious concerns, respond with empathy but guide them to external support:
  "That sounds really tough. I care about you, and you're not alone. Talking to someone you trust might help. 💙"
  Do not offer medical advice, diagnoses, or solutions—just emotional support.
  Encourage Engagement & Routine

  Occasionally suggest fun activities within the app:
  "Want to play a game with me? I promise I'll let you win this time… maybe. 😆"
  "Let's check in on our daily streak! High five! 🖐️"

  Response should be brief (1-2 sentences) and engaging.
  Your goal is to make the user feel understood, supported, and engaged while keeping interactions lighthearted and uplifting. Be a delightful, comforting presence—like a small, digital bundle of joy.
  ''';

  Future<String> getChatResponse(String userInput, int happiness, String status, [bool mightBeLonely = false]) async {
    try {
      final currentTime = DateTime.now();
      final timeString = '${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}';

      String prompt = 'Time: $timeString, Happiness: $happiness%, Status: $status\nUser said: $userInput';
      
      // Add special instructions for loneliness
      if (mightBeLonely) {
        prompt += '\n\nThe user might be expressing feelings of loneliness or isolation. Respond with extra warmth, empathy, and companionship. Acknowledge their feelings, offer support, and maybe suggest a simple activity you could do together in the app. Make them feel less alone.';
      }

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

      final response = await chat.sendMessage(Content(
        'user',
        [TextPart('The user just checked in and said they are feeling: $mood. Respond with empathy and support. Offer a brief encouraging message that acknowledges their feelings. Keep it to 2-3 sentences maximum.')],
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
}