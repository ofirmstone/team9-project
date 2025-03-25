import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Arduino IMU Movement Classifier',
    theme: ThemeData(
      primarySwatch: Colors.blue,
    ),
    home: const ScanScreen(title: 'Arduino IMU Movement Classifier'),
  );
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.title});

  final String title;

  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  String currentGesture = "Unknown";
  final serviceUUID = Guid("19B10000-E8F2-537E-4F6C-D104768A1214");
  final characteristicUUID = Guid("19B10001-E8F2-537E-4F6C-D104768A1215");
  final List<String> targetDeviceName = ["IMUClassifier", "Arduino"];

  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? gestureCharacteristic;

  @override
  void initState() {
    super.initState();

    setState(() {
      currentGesture = "Scanning...";
    });

    scanForDevice();
  }

  void scanForDevice() async {
    if (await FlutterBluePlus.isSupported == false) {
      // output log to show that bluetooth is not supported
      setState(() {
        currentGesture = "Device does not support bluetooth";
      });
      return;
    }

    var bluetoothStatus = await Permission.bluetooth.request();
    var locationStatus = await Permission.location.request();

    if (!bluetoothStatus.isGranted || !locationStatus.isGranted) {
      setState(() {
        currentGesture = "Bluetooth or Location permissions denied";
      });
      return;
    }

    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.turnOn(); // request the user to turn on Bluetooth
      } catch (e) {
        setState(() {
          currentGesture = "Bluetooth request failed: ${e.toString()}";
        });
      }
    }

    FlutterBluePlus.startScan(
      withServices: [serviceUUID],
      withNames: targetDeviceName,
    );

    FlutterBluePlus.scanResults.listen((results) {
      if (results.isNotEmpty) {
        for (ScanResult result in results) {
          connectToDevice(result.device);
        }
      }
    });


  }

  void connectToDevice(BluetoothDevice device) async {
    FlutterBluePlus.stopScan();

    setState(() {
      currentGesture = "Connecting...";
    });

    try {
      await device.connect(autoConnect: true);

      discoverServices(device);

    } catch (e) {
      setState(() {
        currentGesture = "Connection failed: ${e.toString()}";
      });
    }

  }

  void discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();

    for (BluetoothService service in services) {
      if (service.uuid == serviceUUID) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.uuid == characteristicUUID) {
            setState(() {
              currentGesture = "Connected. Waiting for gesture.";
            });

            await characteristic.setNotifyValue(true);

            characteristic.onValueReceived.listen((value) {
              setState(() {
                currentGesture = utf8.decode(value).trim();
              });
            });
          }
        }
      }
    }

    setState(() {
      currentGesture = "Gesture characteristic not found";
    });
  }


  @override
  void dispose() {
    // clear connections
    super.dispose();
  }




  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
    ),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            currentGesture,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: currentGesture == "Scanning..."
                  ? Colors.blue
                  : currentGesture == "Connecting..."
                  ? Colors.orange
                  : ["failed", "denied", "not", "off"].any((word) => currentGesture.contains(word))
                  ? Colors.red
                  : Colors.green,
            ),
            textAlign: TextAlign.center,
          ),

          if (["failed", "denied", "not", "off"].any((word) => currentGesture.contains(word)))
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ElevatedButton(
                onPressed: () => scanForDevice(),
                child: Text('Retry Scan'),
              ),
            ),
        ],
      ),
    ),
  );
}
