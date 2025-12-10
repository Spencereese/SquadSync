import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../services/supabase_service.dart';
import 'onboarding_flow.dart';
import '../../chat/chat_groups_screen.dart';

/// Example integration of OnboardingFlow
///
/// This widget checks if the user needs onboarding and routes accordingly
class OnboardingWrapper extends ConsumerWidget {
  const OnboardingWrapper({super.key});

  Future<Map<String, dynamic>?> _checkOnboardingStatus(String userId) async {
    try {
      final response = await SupabaseService.client
          .from('users')
          .select('onboarding_complete')
          .eq('uid', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error checking onboarding status: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<supabase.User?>(
      stream: supabase.Supabase.instance.client.auth.onAuthStateChange
          .map((data) => data.session?.user),
      builder: (context, authSnapshot) {
        // Show loading while checking auth
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0B0E14),
            body: Center(
              child: CircularProgressIndicator(color: Colors.cyan),
            ),
          );
        }

        final user = authSnapshot.data;

        // Not signed in -> show onboarding
        if (user == null) {
          return const OnboardingFlow();
        }

        // Signed in -> check if onboarding is complete
        return FutureBuilder<Map<String, dynamic>?>(
          future: _checkOnboardingStatus(user.id),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF0B0E14),
                body: Center(
                  child: CircularProgressIndicator(color: Colors.cyan),
                ),
              );
            }

            final userData = userSnapshot.data;
            final onboardingComplete = userData?['onboarding_complete'] == true;

            // Onboarding not complete -> show onboarding flow
            if (!onboardingComplete) {
              return const OnboardingFlow();
            }

            // All good -> show main app
            return const ChatGroupsScreen();
          },
        );
      },
    );
  }
}

/// Usage in main.dart:
/// 
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await Firebase.initializeApp(
///     options: DefaultFirebaseOptions.currentPlatform,
///   );
///   
///   runApp(const ProviderScope(child: MyApp()));
/// }
/// 
/// class MyApp extends StatelessWidget {
///   const MyApp({super.key});
///   
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(
///       title: 'SquadSync',
///       theme: AppTheme.dark(),
///       home: const OnboardingWrapper(), // Use the wrapper
///       routes: {
///         '/onboarding': (context) => const OnboardingFlow(),
///         '/main': (context) => const ChatGroupsScreen(),
///       },
///     );
///   }
/// }
/// ```
