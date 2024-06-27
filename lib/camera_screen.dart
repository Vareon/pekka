import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'dart:io';
import 'gallery_screen.dart';

class CameraScreen extends StatefulWidget {
  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool isRecording = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _checkConnectivityAndUpload();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.high,
    );

    _initializeControllerFuture = _controller.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivityAndUpload() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.mobile || connectivityResult == ConnectivityResult.wifi) {
      final directory = await getExternalStorageDirectory();
      final pekkaDir = Directory('${directory!.path}/Pekka');
      final files = pekkaDir.listSync().whereType<File>().toList();

      for (var file in files) {
        final fileName = file.path.split('/').last;
        final fileType = fileName.split('.').last;
        await uploadFileToFirebase(file.path, fileName.split('.').first, fileType);
      }
    }
  }

  Future<void> uploadFileToFirebase(String filePath, String fileName, String type) async {
    final File file = File(filePath);
    try {
      final storageRef = FirebaseStorage.instance.ref().child('uploads/$fileName.$type');
      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();
      debugPrint("File uploaded to Firebase: $downloadUrl");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('File uploaded to Firebase: $downloadUrl'),
      ));
    } catch (e) {
      debugPrint("Failed to upload to Firebase: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to upload to Firebase: $e'),
      ));
    }
  }

  Future<void> saveFileToGallery(String filePath, String fileType) async {
    if (fileType == 'jpg' || fileType == 'jpeg' || fileType == 'png') {
      await GallerySaver.saveImage(filePath);
    } else if (fileType == 'mp4') {
      await GallerySaver.saveVideo(filePath);
    }
  }

  Future<String> getCustomFilePath(String fileName, String type) async {
    final directory = await getExternalStorageDirectory();
    final path = '${directory!.path}/Pekka';
    final pekkaDir = Directory(path);

    if (!(await pekkaDir.exists())) {
      await pekkaDir.create(recursive: true);
    }

    return '$path/$fileName.$type';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dahili kamera')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FloatingActionButton(
              onPressed: () async {
                try {
                  await _initializeControllerFuture;
                  final path = await getCustomFilePath('photo_${DateTime.now().millisecondsSinceEpoch}', 'jpg');
                  final XFile picture = await _controller.takePicture();
                  await picture.saveTo(path);
                  await saveFileToGallery(path, 'jpg');
                  await uploadFileToFirebase(path, 'photo_${DateTime.now().millisecondsSinceEpoch}', 'jpg');

                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Picture saved to $path'),
                  ));
                } catch (e) {
                  print(e);
                }
              },
              child: Icon(Icons.camera),
            ),
            FloatingActionButton(
              onPressed: () async {
                try {
                  await _initializeControllerFuture;
                  if (isRecording) {
                    final videoFile = await _controller.stopVideoRecording();
                    setState(() {
                      isRecording = false;
                    });
                    final path = await getCustomFilePath('video_${DateTime.now().millisecondsSinceEpoch}', 'mp4');
                    await videoFile.saveTo(path);
                    await saveFileToGallery(path, 'mp4');
                    await uploadFileToFirebase(path, 'video_${DateTime.now().millisecondsSinceEpoch}', 'mp4');

                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Video saved to $path'),
                    ));
                  } else {
                    await _controller.startVideoRecording();
                    setState(() {
                      isRecording = true;
                    });
                  }
                } catch (e) {
                  print(e);
                }
              },
              child: Icon(isRecording ? Icons.stop : Icons.videocam),
            ),
            FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GalleryScreen()),
                );
              },
              child: Icon(Icons.folder),
            ),
          ],
        ),
      ),
    );
  }
}
