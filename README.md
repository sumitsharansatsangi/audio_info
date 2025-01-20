# Audio Info Plugin

A Flutter plugin to retrieve detailed audio information from a specific audio file. This plugin allows you to get metadata such as title, artist, album, album artist, composer, genre, year, track, duration, bitrate, sample rate, and file path.

## Introduction

The Audio Info Plugin provides a simple interface to extract detailed metadata from audio files in your Flutter applications. It supports various audio formats and retrieves comprehensive information about the audio file, making it useful for music players, audio analyzers, and other multimedia applications.

## How to Use

### 1. Add the dependency

Add the following dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  audio_info: ^0.0.1
```

If you want to use the latest version, add this instead:

```yaml
dependencies:
  audio_info:
    git:
      url: https://github.com/sumitsharansatsangi/audio_info.git
```
### 2. Import the plugin

Import the plugin in your Dart code:

```dart
import 'package:audio_info/audio_info.dart';
```
### 3. Get audio information

Use the plugin to retrieve detailed audio information from a specific file:

```dart
import 'package:flutter/material.dart';
import 'package:audio_info/audio_info.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Audio Info Plugin')),
        body: AudioInfoScreen(),
      ),
    );
  }
}

class AudioInfoScreen extends StatefulWidget {
  @override
  _AudioInfoScreenState createState() => _AudioInfoScreenState();
}

class _AudioInfoScreenState extends State<AudioInfoScreen> {
  AudioInfo? audioInfo;

  @override
  void initState() {
    super.initState();
    fetchAudioInfo();
  }

  Future<void> fetchAudioInfo() async {
    // Specify the file path of the audio file
    String filePath = 'path/to/your/audio/file.mp3';

    AudioInfo? info = await AudioInfoPlugin.getAudioInfo(filePath);
    setState(() {
      audioInfo = info;
    });
  }

  @override
  Widget build(BuildContext context) {
    return audioInfo == null
        ? Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Title: ${audioInfo.title}'),
                Text('Album: ${audioInfo.album}'),
                Text('Author: ${audioInfo.author}'),
                Text('Artist: ${audioInfo.artist}'),
                Text('Album Artist: ${audioInfo.albumArtist}'),
                Text('Composer: ${audioInfo.composer}'),
                Text('Genre: ${audioInfo.genre}'),
                Text('Year: ${audioInfo.year}'),
                Text('Track: ${audioInfo.track}'),
                Text('Duration: ${ int.parse(audioInfo.duration) / 1000}s'),
                Text('BitRate: ${audioInfo.bitRate} kbps'),
                Text('Compilation: ${audioInfo.compilation}'),
                Text('Disc Number: ${audioInfo.discNumber}'),
                Text('Date: ${audioInfo.date}'),
              ],
            ),
          );
  }
}

```

## Contribute
We welcome contributions to improve the Audio Info Plugin. If you have any suggestions, bug reports, or feature requests, please open an issue on our GitHub repository.

## Steps to Contribute
1. Fork the repository on GitHub.

2. Create a new branch with your feature or bug fix.

3. Write your code and test it thoroughly.

4. Create a pull request with a clear description of your changes.

Thank you for using and contributing to the Audio Info Plugin!

## License
This project is licensed under the MIT License. See the LICENSE file for more details.