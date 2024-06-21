import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'video_player_screen.dart';

class GalleryScreen extends StatelessWidget {
  Future<List<File>> _getFiles() async {
    final directory = await getExternalStorageDirectory();
    final pekkaDir = Directory('${directory!.path}/Pekka');
    final files = pekkaDir.listSync().whereType<File>().toList();
    return files;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Gallery')),
      body: FutureBuilder<List<File>>(
        future: _getFiles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasData) {
              final files = snapshot.data!;
              return ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];
                  return ListTile(
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
              );
            } else {
              return Center(child: Text('No files found'));
            }
          } else {
            return Center(child: CircularProgressIndicator());
          }
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
