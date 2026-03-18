# audio_info

`audio_info` is a Flutter plugin for reading audio metadata, embedded artwork, and lightweight waveform samples from a local audio file.

Current platform support:
- Android
- iOS

## Features

- Read common metadata such as title, album, artist, composer, genre, year, track, and disc number
- Read extended metadata including author, writer, date, and compilation
- Read technical information such as duration, bitrate, mime type, file size, and quality classification
- Extract embedded album artwork
- Generate waveform sample data for simple visualizations

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  audio_info: ^0.0.6
```

## Import

```dart
import 'package:audio_info/audio_info.dart';
import 'package:audio_info/waveform_widget.dart';
```

## API

### Read metadata

```dart
final AudioData? info = await AudioInfo.getAudioInfo(filePath);
```

### Read embedded artwork

```dart
final Uint8List? artwork = await AudioInfo.getAudioImage(filePath);
```

### Read waveform data

```dart
final List<double> waveform = await AudioInfo.getWaveform(
  filePath,
  samples: 120,
);
```

## AudioData fields

`AudioData` currently exposes:

- `title`
- `album`
- `author`
- `writer`
- `artist`
- `albumArtist`
- `composer`
- `genre`
- `year`
- `date`
- `compilation`
- `trackNumber`
- `discNumber`
- `durationMs`
- `durationSec`
- `durationFormatted`
- `bitrate`
- `bitrateKbps`
- `mimeType`
- `fileSizeBytes`
- `fileSizeMB`
- `quality`
- `hasArtwork`

## Example

```dart
import 'dart:async';

import 'package:audio_info/audio_info.dart';
import 'package:audio_info/waveform_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
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
      home: AudioInfoScreen(),
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

  final AudioPlayer _player = AudioPlayer();

  AudioData? _audioData;
  Uint8List? _embeddedPicture;
  List<double> _waveform = [];

  bool _isPickingFile = false;
  bool _isLoading = false;
  bool _isPlaying = false;
  double _progress = 0.0;
  Duration _duration = Duration.zero;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();

    _positionSub = _player.positionStream.listen((position) {
      if (!mounted || _duration.inMilliseconds == 0) {
        return;
      }

      setState(() {
        _progress = (position.inMilliseconds / _duration.inMilliseconds)
            .clamp(0.0, 1.0);
      });
    });

    _durationSub = _player.durationStream.listen((duration) {
      if (!mounted || duration == null) {
        return;
      }

      setState(() {
        _duration = duration;
      });
    });

    _stateSub = _player.playerStateStream.listen((state) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPlaying = state.playing;
      });
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Info Plugin')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_audioData != null) ...[
              Text(
                _audioData!.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (_waveform.isNotEmpty)
                LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    onTapDown: (details) {
                      if (_duration == Duration.zero) {
                        return;
                      }

                      final fraction =
                          (details.localPosition.dx / constraints.maxWidth)
                              .clamp(0.0, 1.0);
                      _player.seek(
                        Duration(
                          milliseconds:
                              (_duration.inMilliseconds * fraction).round(),
                        ),
                      );
                    },
                    child: SizedBox(
                      width: double.infinity,
                      height: 80,
                      child: WaveformWidget(
                        waveform: _waveform,
                        progress: _progress,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(
                    Duration(
                      milliseconds:
                          (_progress * _duration.inMilliseconds).round(),
                    ),
                  )),
                  Text(_formatDuration(_duration)),
                ],
              ),
              Center(
                child: IconButton(
                  iconSize: 56,
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                  ),
                  onPressed: () {
                    if (_isPlaying) {
                      _player.pause();
                    } else {
                      _player.play();
                    }
                  },
                ),
              ),
              const Divider(height: 24),
              Text('Duration: ${_audioData!.durationFormatted}'),
              Text('Bitrate: ${_audioData!.bitrateKbps} kbps'),
              Text('Mime Type: ${_audioData!.mimeType}'),
            ] else
              const Expanded(
                child: Center(child: Text('No audio file selected')),
              ),
            if (_isPickingFile || _isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
            Center(
              child: ElevatedButton(
                onPressed:
                    (_isPickingFile || _isLoading) ? null : () => pickFile(context),
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
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> pickFile(BuildContext context) async {
    if (_isPickingFile || _isLoading) {
      return;
    }

    setState(() {
      _isPickingFile = true;
    });

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: defaultTargetPlatform == TargetPlatform.iOS
            ? FileType.any
            : FileType.custom,
        allowedExtensions: const [
          'mp3',
          'm4a',
          'aac',
          'wav',
          'flac',
          'ogg',
          'opus',
          'aiff',
          'wma',
        ],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final String filePath = result.files.single.path!;

      setState(() {
        _isLoading = true;
      });

      final AudioData? info =
          await AudioInfo.getAudioInfo(filePath).timeout(_processingTimeout);
      final Uint8List? artwork =
          await AudioInfo.getAudioImage(filePath).timeout(_processingTimeout);
      final List<double> waveform =
          await AudioInfo.getWaveform(filePath, samples: 120)
              .timeout(_processingTimeout);

      await _player.setFilePath(filePath);

      if (!mounted) {
        return;
      }

      setState(() {
        _audioData = info;
        _embeddedPicture = artwork;
        _waveform = waveform;
        _progress = 0.0;
      });
    } on PlatformException catch (error) {
      if (!context.mounted) {
        return;
      }

      final String message = error.code == 'multiple_request'
          ? 'Please wait for the current file picker request to finish.'
          : error.message ?? 'Failed to pick audio file.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on TimeoutException {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading audio info timed out. Please try another file.'),
        ),
      );
    } finally {
      if (!mounted) {
        return;
      },

      setState(() {
        _isPickingFile = false;
        _isLoading = false;
      });
    }
  }
}
```

## Notes

- `getWaveform` returns sampled amplitude values intended for lightweight UI rendering.
- The waveform output is approximate and depends on the source format and Android media stack behavior.
- Metadata availability varies by audio file format and embedded tags.

## Contributing

Issues and pull requests are welcome on the repository:

`https://github.com/sumitsharansatsangi/audio_info/`

## License

This project is licensed under the MIT License. See `LICENSE`.
