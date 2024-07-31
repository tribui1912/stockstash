import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'dart:math';
import 'package:getwidget/getwidget.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'dart:ui';



void main() {
  runApp(const CabinetsApp());
}

class CabinetsApp extends StatelessWidget {
  const CabinetsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const MainMenu(),
    );
  }
}

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
    setState(() {
      _nfcAvailable = isAvailable;
    });
  }

  Future<void> toggleNfc() async {
    if (_nfcActive) {
      await disableForegroundDispatch();
    } else {
      await enableForegroundDispatch();
      // Automatically disable NFC after 1 minute
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
    setState(() {
      _nfcActive = true;
    });
  }

  Future<void> disableForegroundDispatch() async {
    await NfcManager.instance.stopSession();
    setState(() {
      _nfcActive = false;
    });
  }

  void _handleTag(NfcTag tag) async {
    Ndef? ndef = Ndef.from(tag);
    if (ndef == null) {
      print('Tag is not NDEF.');
      return;
    }

    NdefMessage? message = await ndef.read();
    if (message != null && message.records.isNotEmpty) {
      NdefRecord record = message.records.first;
      String payload = String.fromCharCodes(record.payload).substring(3);
      print("Read NFC Tag: $payload");
      _openCabinetWithKey(context, payload);
    }
  }

  void _openCabinetWithKey(BuildContext context, String key) async {
    DatabaseHelper dbHelper = DatabaseHelper();
    List<Cabinet> cabinets = await dbHelper.getCabinets();
    
    print("NFC Tag Key: $key");
    print("All Cabinets: ${cabinets.map((c) => '${c.id}: ${c.name} (${c.data})')}");

    Cabinet? cabinetToOpen;
    try {
      cabinetToOpen = cabinets.firstWhere(
        (cabinet) => cabinet.data == key,
      );
    } catch (e) {
      cabinetToOpen = null;
    }

    if (cabinetToOpen != null) {
      print("Opening cabinet: ${cabinetToOpen.id}: ${cabinetToOpen.name} (${cabinetToOpen.data})");
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => ItemsPage(cabinet: cabinetToOpen!),
        ),
      );
    } else {
      print("No cabinet found with key: $key");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No cabinet found with this NFC tag')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('StockStash', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue.withOpacity(0.8),
                    Colors.blue.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[300]!, Colors.blue[100]!],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CupertinoButton(
                  color: CupertinoColors.white,
                  child: Text('View Cabinets', style: TextStyle(color: CupertinoColors.activeBlue)),
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
                    color: _nfcActive ? CupertinoColors.activeGreen : CupertinoColors.white,
                    child: Text(
                      _nfcActive ? 'NFC Active' : 'Activate NFC',
                      style: TextStyle(color: _nfcActive ? CupertinoColors.white : CupertinoColors.activeBlue),
                    ),
                    onPressed: toggleNfc,
                  )
                else
                  Text(
                    'NFC is not available on this device',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: CupertinoColors.white),
                  ),
                SizedBox(height: 20),
                Text(
                  _nfcActive 
                      ? 'NFC is active. Tap an NFC tag to read.\nNFC will deactivate automatically after 1 minute.' 
                      : 'Tap the button above to activate NFC for 1 minute.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CupertinoColors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CabinetsPage extends StatefulWidget {
  const CabinetsPage({super.key});

  @override
  State<CabinetsPage> createState() => _CabinetsPageState();
}

class _CabinetsPageState extends State<CabinetsPage> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<Cabinet> _cabinets = [];

  @override
  void initState() {
    super.initState();
    _loadCabinets();
  }

  void _loadCabinets() async {
    List<Cabinet> cabinets = await dbHelper.getCabinets();
    setState(() {
      _cabinets = cabinets;
    });
  }

  void _addCabinet(Cabinet cabinet) async {
    int id = await dbHelper.insertCabinet(cabinet);
    setState(() {
      _cabinets.add(Cabinet(id, cabinet.name, cabinet.data));
    });
  }

  void _removeCabinet(Cabinet cabinet) async {
    await dbHelper.removeCabinet(cabinet.id);
    setState(() {
      _cabinets.remove(cabinet);
    });
  }

  Future<void> _showRemoveConfirmationDialog(BuildContext context, Cabinet cabinet) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Remove Cabinet'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to remove "${cabinet.name}"?'),
                Text('This action cannot be undone.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Remove'),
              onPressed: () {
                Navigator.of(context).pop();
                _removeCabinet(cabinet);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Icon(Icons.warehouse, color: Colors.white),
        title: const Text('StockStash', style: TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue[700]!, Colors.blue[500]!],
            ),
          ),
        ),
      ),
      body: GridView.builder(
        padding: EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _cabinets.length,
        itemBuilder: (context, index) {
          var cabinet = _cabinets[index];
          return GestureDetector(
            onLongPress: () => _showRemoveConfirmationDialog(context, cabinet),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ItemsPage(cabinet: cabinet),
                    ),
                  ).then((_) => _loadCabinets());
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.storage, size: 48, color: Colors.blue),
                    SizedBox(height: 8),
                    Text(
                      cabinet.name,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text('${cabinet.items.length} items'),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddCabinetDialog(onAdd: _addCabinet),
          );
        },
        icon: Icon(Icons.add),
        label: Text('Add Cabinet'),
        backgroundColor: Colors.blue[700],
      ),
    );
  }
}

class Cabinet {
  final int id;
  final String name;
  final String data;
  final List<Item> items;

  Cabinet(this.id, this.name, this.data, {List<Item>? items}) : this.items = items ?? [];
}

class Item {
  final int id;
  final String name;
  int count;

  Item(this.id, this.name, this.count);
}

class ItemsPage extends StatefulWidget {
  final Cabinet cabinet;

  const ItemsPage({super.key, required this.cabinet});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  late List<Item> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.cabinet.items);
  }

  void _addItem(String name, int count) async {
    Item newItem = Item(0, name, count);
    int id = await dbHelper.insertItem(newItem, widget.cabinet.id);
    setState(() {
      _items.add(Item(id, name, count));
    });
  }

  void _updateItemCount(Item item, int delta) async {
    int newCount = item.count + delta;
    if (newCount > 0) {
      await dbHelper.updateItemCount(item, delta);
      setState(() {
        item.count = newCount;
      });
    } else {
      await dbHelper.removeItem(item.id);
      setState(() {
        _items.remove(item);
      });
    }
  }

  void _removeItem(Item item) async {
    await dbHelper.removeItem(item.id);
    setState(() {
      _items.remove(item);
    });
  }

  Future<void> _showRemoveConfirmationDialog(BuildContext context, Item item) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Remove Item'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to remove "${item.name}"?'),
                Text('This action cannot be undone.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Remove'),
              onPressed: () {
                Navigator.of(context).pop();
                _removeItem(item);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cabinet.name, style: TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue[700]!, Colors.blue[500]!],
            ),
          ),
        ),
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          var item = _items[index];
          return GestureDetector(
            onLongPress: () => _showRemoveConfirmationDialog(context, item),
            child: Card(
              margin: EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(
                  item.name,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Quantity: ${item.count}',
                  style: TextStyle(fontSize: 16),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () => _updateItemCount(item, -1),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline, color: Colors.green),
                      onPressed: () => _updateItemCount(item, 1),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddItemDialog(onAdd: _addItem),
          );
        },
        icon: Icon(Icons.add),
        label: Text('Add Item'),
        backgroundColor: Colors.blue[700],
      ),
    );
  }
}

class AddCabinetDialog extends StatelessWidget {
  final Function(Cabinet) onAdd;

  const AddCabinetDialog({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    TextEditingController nameController = TextEditingController();

    return AlertDialog(
      title: const Text('Add Cabinet'),
      content: TextField(
        controller: nameController,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            onAdd(Cabinet(0, nameController.text, ''));
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class AddItemDialog extends StatelessWidget {
  final Function(String, int) onAdd;

  const AddItemDialog({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    TextEditingController nameController = TextEditingController();
    TextEditingController countController = TextEditingController(text: '1');

    return AlertDialog(
      title: const Text('Add Item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: countController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Count'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            onAdd(nameController.text, int.parse(countController.text));
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}