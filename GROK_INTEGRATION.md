# Grok AI Integration for SquadSync

## Overview
Grok AI has been integrated into the SquadSync chat system to provide helpful gaming assistance and squad management support.

## Features
- **Smart Chat Detection**: Messages starting with "@grok", "grok", "hey grok", or "hi grok" trigger AI responses
- **Gaming Context Awareness**: Grok understands gaming terminology and squad management
- **Special UI**: AI responses appear with "Grok 🤖" as the sender name in blue accent color

## Setup
1. Get your xAI API key from https://console.x.ai/
2. In `lib/main.dart`, uncomment and run the Grok setup code:
   ```dart
   final grokService = GrokService();
   await grokService.storeApiKey();
   ```
3. Comment out the setup code after first run

## Usage Examples
Users can ask Grok questions like:
- "@grok What are some good strategies for Warzone?"
- "grok help me with squad composition for Apex Legends"
- "hey grok what games should we play tonight?"
- "hi grok how do I improve my aim in Valorant?"

## Technical Details
- **Service**: `lib/services/grok_service.dart`
- **Integration**: `lib/chat/chat_service.dart` (message processing)
- **UI**: `lib/chat/message_bubble.dart` (special AI message styling)
- **API**: xAI Grok API with gaming-focused system prompts

## Fallback Behavior
If the API is unavailable, Grok provides helpful fallback responses based on common gaming queries.