import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioBubble extends StatefulWidget {
  final String url;
  final int durationMs;

  const AudioBubble({
    super.key,
    required this.url,
    required this.durationMs,
  });

  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<AudioBubble> {
  final _player = AudioPlayer();
  bool _ready = false;
  StreamSubscription<Duration>? _posSub;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setUrl(widget.url);
      _dur = _player.duration ?? Duration(milliseconds: widget.durationMs);
      _posSub = _player.positionStream.listen((d) {
        setState(() => _pos = d);
      });
      setState(() => _ready = true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final playing = _player.playing;
    return SizedBox(
      width: 240,
      child: Row(
        children: [
          IconButton(
            onPressed:
            !_ready ? null : () => playing ? _player.pause() : _player.play(),
            icon: Icon(playing ? Icons.pause : Icons.play_arrow,
                color: Colors.white),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: _pos.inMilliseconds
                      .clamp(0, _dur.inMilliseconds)
                      .toDouble(),
                  max: _dur.inMilliseconds.toDouble().clamp(1, 1e9),
                  onChanged: !_ready
                      ? null
                      : (v) =>
                      _player.seek(Duration(milliseconds: v.toInt())),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(_pos),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                    Text(_fmt(_dur),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
