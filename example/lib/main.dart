import 'dart:async';

import 'package:audio_info/audio_info.dart';
import 'package:audio_info/waveform_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const AudioInfoScreen(),
    );
  }
}

class AudioInfoScreen extends StatefulWidget {
  const AudioInfoScreen({super.key});

  @override
  State<AudioInfoScreen> createState() => _AudioInfoScreenState();
}

class _AudioInfoScreenState extends State<AudioInfoScreen> {
  static const Duration _processingTimeout = Duration(seconds: 20);

  bool _isLoading = false;
  bool _isPickingFile = false;

  final AudioPlayer _player = AudioPlayer();

  AudioData? _audioData;
  Uint8List? _embeddedPicture;
  List<double> _waveform = [];

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Info Plugin')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isPickingFile || _isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: CircularProgressIndicator(),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isLoading || _isPickingFile)
                      ? null
                      : () => pickFile(context),
                  child: Text(
                    _isPickingFile
                        ? 'Opening...'
                        : _isLoading
                            ? 'Loading...'
                            : 'Choose Audio File',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_audioData != null) ...[
              // Artwork — wrapped in RepaintBoundary so it never repaints
              if (_embeddedPicture != null && _embeddedPicture!.isNotEmpty)
                Center(
                  child: RepaintBoundary(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _embeddedPicture!,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                _audioData!.title,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (_audioData!.artist.isNotEmpty)
                Text(
                  _audioData!.artist,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              const SizedBox(height: 20),

              // Player controls — isolated widget; only this subtree rebuilds
              // on every position tick.
              if (_waveform.isNotEmpty)
                _PlayerControls(player: _player, waveform: _waveform),

              const Divider(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _metadataRow('Album', _audioData!.album),
                      _metadataRow('Album Artist', _audioData!.albumArtist),
                      _metadataRow('Artist', _audioData!.artist),
                      _metadataRow('Composer', _audioData!.composer),
                      _metadataRow('Genre', _audioData!.genre),
                      _metadataRow('Year', _audioData!.year),
                      _metadataRow('Track', _audioData!.trackNumber),
                      Text('Duration: ${_audioData!.durationFormatted}'),
                      Text('Bitrate: ${_audioData!.bitrateKbps} kbps'),
                      Text('Quality: ${_audioData!.quality}'),
                      Text('Mime Type: ${_audioData!.mimeType}'),
                      Text(
                        'File Size: ${_audioData!.fileSizeMB.toStringAsFixed(2)} MB',
                      ),
                    ],
                  ),
                ),
              ),
            ] else
              const Expanded(
                child: Center(child: Text('No audio file selected')),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> pickFile(BuildContext context) async {
    if (_isLoading || _isPickingFile) return;

    setState(() => _isPickingFile = true);

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg', 'opus', 'aiff', 'wma',
        ],
      );

      if (result == null || result.files.single.path == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No audio file selected')),
          );
        }
        return;
      }

      final String filePath = result.files.single.path!;
      if (mounted) setState(() => _isLoading = true);

      await _player.stop();

      // Run all heavy operations in parallel.
      final results = await Future.wait<dynamic>([
        AudioInfo.getAudioInfo(filePath),
        AudioInfo.getAudioImage(filePath),
        AudioInfo.getWaveform(filePath, samples: 120),
        _player.setFilePath(filePath),
      ]).timeout(_processingTimeout);

      final audioInfo = results[0] as AudioData?;
      final embeddedPicture = results[1] as Uint8List?;
      final waveform = List<double>.from(results[2] as List);

      if (!mounted) return;

      setState(() {
        _audioData = audioInfo;
        _embeddedPicture = embeddedPicture;
        _waveform = waveform;
      });

      _player.play();
    } on PlatformException catch (error) {
      if (!context.mounted) return;
      final message = error.code == 'multiple_request'
          ? 'Please wait for the current file picker request to finish.'
          : error.message?.isNotEmpty == true
              ? error.message!
              : 'Failed to pick audio file.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on TimeoutException catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading audio info timed out. Please try another file.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingFile = false;
          _isLoading = false;
        });
      }
    }
  }
}

/// Isolated widget for waveform + timer + play/pause.
/// Only this subtree rebuilds on every position tick — the rest of the
/// screen (artwork, metadata text) is untouched.
class _PlayerControls extends StatefulWidget {
  final AudioPlayer player;
  final List<double> waveform;

  const _PlayerControls({required this.player, required this.waveform});

  @override
  State<_PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<_PlayerControls> {
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _posSub = widget.player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _durSub = widget.player.durationStream.listen((dur) {
      if (dur != null && mounted) setState(() => _duration = dur);
    });
    _stateSub = widget.player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);
      if (state.processingState == ProcessingState.completed) {
        widget.player.seek(Duration.zero);
        widget.player.pause();
        if (mounted) setState(() => _position = Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        LayoutBuilder(
          builder: (ctx, constraints) => GestureDetector(
            onTapDown: (details) {
              if (_duration == Duration.zero) return;
              final fraction =
                  (details.localPosition.dx / constraints.maxWidth)
                      .clamp(0.0, 1.0);
              widget.player.seek(Duration(
                milliseconds: (fraction * _duration.inMilliseconds).round(),
              ));
            },
            // RepaintBoundary isolates waveform repaints from the timer/button
            child: RepaintBoundary(
              child: SizedBox(
                width: double.infinity,
                height: 80,
                child: WaveformWidget(
                  waveform: widget.waveform,
                  progress: progress,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(_position)),
            Text(_fmt(_duration)),
          ],
        ),
        Center(
          child: IconButton(
            iconSize: 56,
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: const Color(0xFF4A3B8F),
            ),
            onPressed: () =>
                _isPlaying ? widget.player.pause() : widget.player.play(),
          ),
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

Widget _metadataRow(String label, String value) {
  if (value.trim().isEmpty) return const SizedBox.shrink();
  return Text('$label: $value');
}
