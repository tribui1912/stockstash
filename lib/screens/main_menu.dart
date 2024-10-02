import 'package:flutter/cupertino.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'dart:async';
import '../utils/database_helper.dart';
import '../models/cabinet.dart';
import 'cabinets_page.dart';
import 'items_page.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> with WidgetsBindingObserver {
  bool _nfcActive = false;
  bool _nfcAvailable = false;
  Timer? _nfcTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNfcAvailability();
  }

  @override
  void dispose() {
    _nfcTimer?.cancel();
    disableForegroundDispatch();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNfcAvailability();
    } else if (state == AppLifecycleState.paused) {
      disableForegroundDispatch();
    }
  }

  Future<void> _checkNfcAvailability() async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (mounted) {
      setState(() {
        _nfcAvailable = isAvailable;
      });
    }
  }

  Future<void> toggleNfc() async {
    if (_nfcActive) {
      await disableForegroundDispatch();
    } else {
      await enableForegroundDispatch();
      _nfcTimer = Timer(Duration(minutes: 1), () {
        disableForegroundDispatch();
      });
    }
  }

  Future<void> enableForegroundDispatch() async {
    await NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        _handleTag(tag);
      },
    );
    if (mounted) {
      setState(() {
        _nfcActive = true;
      });
    }
  }

  Future<void> disableForegroundDispatch() async {
    await NfcManager.instance.stopSession();
    if (mounted) {
      setState(() {
        _nfcActive = false;
      });
    }
  }

  void _handleTag(NfcTag tag) async {
    Ndef? ndef = Ndef.from(tag);
    if (ndef == null) {
      print('Tag is not NDEF.');
      return;
    }

    NdefMessage message = await ndef.read();
    if (message.records.isNotEmpty) {
      NdefRecord record = message.records.first;
      String payload = String.fromCharCodes(record.payload).substring(3);
      print("Read NFC Tag: $payload");
      if (mounted) {
        _openCabinetWithKey(context, payload);
      }
    } else {
      print('NDEF message is empty.');
    }
  }

  void _openCabinetWithKey(BuildContext context, String key) async {
    if (!mounted) return;

    DatabaseHelper dbHelper = DatabaseHelper();
    List<Cabinet> cabinets = await dbHelper.getCabinets();
    
    if (!mounted) return;

    Cabinet? cabinetToOpen = cabinets.firstWhere(
      (cabinet) => cabinet.data == key,
      orElse: () => Cabinet(-1, '', ''), // Return a dummy cabinet if not found
    );

    if (cabinetToOpen.id != -1) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => ItemsPage(cabinet: cabinetToOpen),
        ),
      );
    } else {
      if (!context.mounted) return;
      _showNoCabinetFoundDialog(context);
    }
  }

  void _showNoCabinetFoundDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext dialogContext) => CupertinoAlertDialog(
        title: Text('No Cabinet Found'),
        content: Text('No cabinet found with this NFC tag'),
        actions: [
          CupertinoDialogAction(
            child: Text('OK'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('StockStash'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CupertinoButton.filled(
                child: Text('View Cabinets'),
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => CabinetsPage()),
                  );
                },
              ),
              SizedBox(height: 20),
              if (_nfcAvailable)
                CupertinoButton(
                  color: _nfcActive ? CupertinoColors.activeGreen : CupertinoColors.activeBlue,
                  onPressed: toggleNfc,
                  child: Text(_nfcActive ? 'NFC Active' : 'Activate NFC'),
                )
              else
                const Text(
                  'NFC is not available on this device',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CupertinoColors.secondaryLabel),
                ),
              const SizedBox(height: 20), 
              Text(
                _nfcActive 
                    ? 'NFC is active. Tap an NFC tag to read.\nNFC will deactivate automatically after 1 minute.' 
                    : 'Tap the button above to activate NFC for 1 minute.',
                textAlign: TextAlign.center,
                style: TextStyle(color: CupertinoColors.secondaryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
