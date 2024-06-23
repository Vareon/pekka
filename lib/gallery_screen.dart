import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'video_player_screen.dart';

class GalleryScreen extends StatefulWidget {
  @override
  _GalleryScreenState createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<File> _files = [];
  List<bool> _selectedFiles = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final directory = await getExternalStorageDirectory();
    final pekkaDir = Directory('${directory!.path}/Pekka');
    if (await pekkaDir.exists()) {
      final files = pekkaDir.listSync().whereType<File>().toList();
      setState(() {
        _files = files;
        _selectedFiles = List<bool>.filled(files.length, false);
      });
    }
  }

  Future<void> _deleteSelectedFiles() async {
    for (int i = 0; i < _files.length; i++) {
      if (_selectedFiles[i]) {
        await _files[i].delete();
      }
    }
    _loadFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gallery'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _deleteSelectedFiles,
          ),
        ],
      ),
      body: _files.isEmpty
          ? Center(child: Text('No files found'))
          : ListView.builder(
        itemCount: _files.length,
        itemBuilder: (context, index) {
          final file = _files[index];
          return ListTile(
            leading: Checkbox(
              value: _selectedFiles[index],
              onChanged: (bool? value) {
                setState(() {
                  _selectedFiles[index] = value!;
                });
              },
            ),
            title: Text(file.path.split('/').last),
            onTap: () {
              if (file.path.endsWith('.mp4')) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerScreen(file: file),
                  ),
                );
              } else if (file.path.endsWith('.jpg') || file.path.endsWith('.png')) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImageScreen(file: file),
                  ),
                );
              } else {
                // Handle other file types if needed
              }
            },
          );
        },
      ),
    );
  }
}

class ImageScreen extends StatelessWidget {
  final File file;

  ImageScreen({required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Image Preview')),
      body: Center(
        child: Image.file(file),
      ),
    );
  }
}
