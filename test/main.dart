import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/core/injection.dart' as di;
import 'package:squad_sync/test/helpers/test_injection.dart';

/// Test app wrapper with ProviderScope for widget tests
class TestApp extends StatelessWidget {
  final Widget child;

  const TestApp({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        // Override providers with mocks if needed
        // Example: userNotifierProvider.overrideWith(() => MockUserNotifier()),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }
}

/// Setup function for tests requiring ProviderScope
void setupTestApp() {
  // Setup mock dependencies
  setupTestDependencies();

  // Additional test-specific setup can go here
  WidgetsFlutterBinding.ensureInitialized();
}