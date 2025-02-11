import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blueGrey),
      home: const QRViewExample(),
    );
  }
}

class QRViewExample extends StatefulWidget {
  const QRViewExample({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _QRViewExampleState();
}

class _QRViewExampleState extends State<QRViewExample> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? result;
  QRViewController? controller;

  @override
  void reassemble() {
    super.reassemble();
    controller!.pauseCamera();
    controller!.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Safe Scanner')),
      body: Column(
        children: <Widget>[
          Expanded(flex: 4, child: _buildQrView(context)),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (result != null)
                  Text('Result: ${result!.code}')
                else
                  const Text('Scan a code'),
                ElevatedButton(
                  onPressed: result != null && result!.code != null
                      ? () => _checkWithVirusTotal(result!.code!)
                      : null,
                  child: const Text('Check with VirusTotal'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
        borderColor: Colors.white,
        borderRadius: 10,
        borderLength: 30,
        borderWidth: 10,
        cutOutSize: 300, // MediaQuery.of(context).size.width * 0.8,
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    controller.scannedDataStream.listen((scanData) {
      setState(() {
        result = scanData;
      });
    });
  }

  Future<void> _checkWithVirusTotal(String url) async {
    const apiKey = ''; //masukkan api key dari virus total
    final encodedUrl = base64Url.encode(utf8.encode(url)).replaceAll('=', '');
    final apiUrl = 'https://www.virustotal.com/api/v3/urls/$encodedUrl';

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'x-apikey': apiKey,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final scanResult =
            jsonResponse['data']['attributes']['last_analysis_stats'];

        // Periksa apakah malicious atau suspicious lebih dari 0
        if (scanResult['malicious'] > 0 || scanResult['suspicious'] > 0) {
          _showWarningDialog('Link/URL Website Berbahaya');
        } else {
          // Tampilkan popup untuk membuka URL di browser
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('VirusTotal Result'),
              content:
                  Text('URL aman. Apakah Anda ingin membuka URL ini?\n\n$url'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Batal'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Buka'),
                  onPressed: () async {
                    Navigator.of(context).pop(); // Tutup popup
                    await _launchURL(url); // Buka URL di browser
                  },
                ),
              ],
            ),
          );
        }
      } else {
        _showErrorDialog('Error: Unable to scan the URL with VirusTotal.');
      }
    } catch (e) {
      _showErrorDialog('Error: $e');
    }
  }

// Fungsi untuk membuka URL di browser
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showErrorDialog('Tidak dapat membuka URL: $url');
    }
  }

  void _showWarningDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Warning'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
