import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pekka62/web_socket_frame_screen.dart';
import 'camera_screen.dart';
//import 'stream_screen.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await requestPermissions();

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

Future<void> requestPermissions() async {
  var status = await Permission.storage.request();
  if (status.isGranted) {
    print('Storage permission granted');
  } else {
    print('Storage permission denied');
  }

  status = await Permission.camera.request();
  if (status.isGranted) {
    print('Camera permission granted');
  } else {
    print('Camera permission denied');
  }

  status = await Permission.microphone.request();
  if (status.isGranted) {
    print('Microphone permission granted');
  } else {
    print('Microphone permission denied');
  }

  status = await Permission.photos.request();
  if (status.isGranted) {
    print('Photos permission granted');
  } else {
    print('Photos permission denied');
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select Camera')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CameraScreen(),
                  ),
                );
              },

              child: Text('Dahili kamera'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoStream(),
                  ),
                );
              },
              child: Text('RaspberryPi yayını'),
            ),
          ],
        ),
      ),
    );
  }
}
