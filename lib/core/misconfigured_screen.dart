import 'package:flutter/material.dart';

/// Config was present and the Supabase client was not. Do not show fakes.
class MisconfiguredScreen extends StatelessWidget {
  const MisconfiguredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Not connected',
                key: Key('link-misconfigured'),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text(
                'SquadSync has a project URL, but the client did not start. '
                'This phone is not in the live squad, and demo messages '
                'are not being shown.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
