import 'dart:typed_data';
import 'dart:ui';

import 'package:bluetooth_thermal_printer/bluetooth_thermal_printer.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:image/image.dart' as img;
import 'package:screenshot/screenshot.dart';
import 'package:sunmi_printer_plus/enums.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:sunmi_printer_plus/sunmi_style.dart';
import 'package:wifi_info_flutter/wifi_info_flutter.dart';
ScreenshotController screenshotController = ScreenshotController();
TextEditingController bluController=TextEditingController();


void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Printing Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: PrintScreen(),
    );
  }
}

class PrintScreen extends StatefulWidget {
  @override
  _PrintScreenState createState() => _PrintScreenState();
}

class _PrintScreenState extends State<PrintScreen> {
  Future<String?> _getWifiIP() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.wifi) {
      String? ipAddress = await WifiInfo().getWifiIP();
      return ipAddress?.toString();
    } else {
      return null;
    }
  }

  void _printReceipt(NetworkPrinter printer) {
    printer.text('text1');
    printer.text('text2', styles: PosStyles(codeTable: 'CP1252'));
    printer.text('Special 2: blåbærgrød', styles: PosStyles(codeTable: 'CP1252'));

    printer.text('Bold text', styles: PosStyles(bold: true));
    printer.text('Reverse text', styles: PosStyles(reverse: true));
    printer.text('Underlined text', styles: PosStyles(underline: true), linesAfter: 1);
    printer.text('Align left', styles: PosStyles(align: PosAlign.left));
    printer.text('Align center', styles: PosStyles(align: PosAlign.center));
    printer.text('Align right', styles: PosStyles(align: PosAlign.right), linesAfter: 1);

    printer.text('Text size 200%', styles: PosStyles(height: PosTextSize.size2, width: PosTextSize.size2));

    printer.feed(2);
    printer.cut();
  }

  Future<void> _printViaWiFi(String ipAddress) async {
    const PaperSize paper = PaperSize.mm80;
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(paper, profile);

    final PosPrintResult res = await printer.connect(_convertArabicToEnglish(ipAddress), port: 9100);

    if (res == PosPrintResult.success) {
      _printReceipt(printer);
      printer.disconnect();
    }

    print('Print result: ${res.msg}');
  }

  Future<void> _printViaBluetooth(String macBluetooth) async {
    final isConnected = await BluetoothThermalPrinter.connect(macBluetooth);
    if (isConnected == "true") {
      final bytes = await _getTicket();
      final result = await BluetoothThermalPrinter.writeBytes(bytes);
      print("Print $result");
    } else {
      // Handle not connected scenario
    }
  }

  Future<void> _printPosHandMade() async {
    SunmiPrinter.printText(
      'saed pay',
      style: SunmiStyle(align: SunmiPrintAlign.CENTER, fontSize: SunmiFontSize.MD),
    );
    SunmiPrinter.resetBold();
  }

  Future<List<int>> _getTicket() async {
    List<int> bytes = [];

    final profile = await CapabilityProfile.load(name: 'XP-N160I');
    final generator = Generator(PaperSize.mm58, profile);

    bytes += generator.setGlobalCodeTable('CP1252');

    final img.Image? image = img.decodeImage(await screenshotController.capture()??Uint8List(0));    img.Image thumbnail = img.copyResize(image!, width: PaperSized.mm80.width);
    bytes += generator.image(thumbnail, align: PosAlign.right);

    bytes += generator.feed(1);
    bytes += generator.feed(1);
    bytes += generator.feed(1);

    return bytes;
  }

  String _convertArabicToEnglish(String arabicText) {
    const Map<String, String> arabicToEnglish = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
    };

    String englishText = '';
    for (int i = 0; i < arabicText.length; i++) {
      englishText += arabicToEnglish[arabicText[i]] ?? arabicText[i];
    }
    return englishText;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Print Example'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextFormField(
              controller: bluController,

            ),
            ElevatedButton(
              onPressed: () async {
                String? ipAddress = await _getWifiIP();
                String ? enIpaddress=_convertArabicToEnglish(ipAddress!);
                if (enIpaddress != null) {
                  setState(() {
                    bluController.text=enIpaddress;

                  });
                  _printViaWiFi(enIpaddress);
                } else {
                  // Handle case when Wi-Fi is not connected
                }
              },
              child: Text('Print via Wi-Fi'),
            ),
            ElevatedButton(
              onPressed: () async {
                final List<dynamic>? bluetoothInfo = await _getBluetooth();
                if (bluetoothInfo != null && bluetoothInfo.isNotEmpty) {
                  final macBluetooth = bluetoothInfo[0].split("#")[1];
                  print(">>>>>>>>>>>>>>>>>>>"+macBluetooth);
                  setState(() {
                    bluController.text=macBluetooth;

                  });
                  _printViaBluetooth(macBluetooth);
                } else {
                  _printPosHandMade();
                }
              },
              child: Text('Print via Bluetooth'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<dynamic>?> _getBluetooth() async {
    final List? bluetooths = await BluetoothThermalPrinter.getBluetooths;
    print("Bluetooths: $bluetooths");
    return bluetooths;
  }
}

class PaperSized {
  const PaperSized._internal(this.value);
  final int value;
  static const mm58 = PaperSized._internal(1);
  static const mm80 = PaperSized._internal(2);
  int get width => value == PaperSized.mm58.value ? 375 : 500;
}
