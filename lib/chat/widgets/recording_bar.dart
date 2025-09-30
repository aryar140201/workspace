import 'package:flutter/material.dart';

class RecordingBar extends StatelessWidget {
  final int ms;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  const RecordingBar({
    super.key,
    required this.ms,
    required this.onStop,
    required this.onCancel,
  });

  String _fmt(int ms) {
    final d = Duration(milliseconds: ms);
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red.withOpacity(0.08),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.mic, color: Colors.red),
          const SizedBox(width: 8),
          Text('Recording… ${_fmt(ms)}'),
          const Spacer(),
          TextButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close),
            label: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.send),
            label: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
