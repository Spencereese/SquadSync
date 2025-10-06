import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../squad_state.dart';

class CreateSquadScreen extends StatefulWidget {
  const CreateSquadScreen({super.key});

  @override
  _CreateSquadScreenState createState() => _CreateSquadScreenState();
}

class _CreateSquadScreenState extends State<CreateSquadScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _showCode = false;
  String? _inviteCode;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_showCode ? 'Squad Created!' : 'Create Squad'),
      content: _showCode
          ? _buildCodeContent()
          : TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: 'Squad Name'),
            ),
      actions: _showCode
          ? _buildCodeActions()
          : [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: _createSquad,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Create'),
              ),
            ],
    );
  }

  Widget _buildCodeContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
            'Your squad has been created! Share this code with friends:'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _copyCode,
                  child: Text(
                    _inviteCode!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: _copyCode,
                tooltip: 'Copy code',
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap the code to copy it',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  List<Widget> _buildCodeActions() {
    return [
      TextButton.icon(
        onPressed: _shareCode,
        icon: const Icon(Icons.share),
        label: const Text('Share'),
      ),
      TextButton.icon(
        onPressed: _sendViaSMS,
        icon: const Icon(Icons.message),
        label: const Text('SMS'),
      ),
      ElevatedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Done'),
      ),
    ];
  }

  Future<void> _createSquad() async {
    if (_nameController.text.isEmpty || !mounted) return;
    setState(() => _isLoading = true);
    try {
      final squadState = Provider.of<SquadState>(context, listen: false);
      final squadId = await squadState.createSquad(_nameController.text);
      final inviteCode = await FirebaseFirestore.instance
          .collection('squads')
          .doc(squadId)
          .get()
          .then((doc) => doc.data()?['inviteCode']);
      setState(() {
        _inviteCode = inviteCode;
        _showCode = true;
        _isLoading = false;
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _inviteCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copied to clipboard')),
    );
    HapticFeedback.lightImpact();
  }

  void _shareCode() {
    Share.share('Join my SquadSync squad with code: $_inviteCode');
  }

  void _sendViaSMS() async {
    final message = 'Join my SquadSync squad with code: $_inviteCode';
    final smsUri = Uri(scheme: 'sms', queryParameters: {'body': message});
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      // Fallback to share if SMS not available
      _shareCode();
    }
  }
}
