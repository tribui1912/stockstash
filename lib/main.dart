import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'dart:math';

void main() {
  runApp(const CabinetsApp());
}

class CabinetsApp extends StatelessWidget {
  const CabinetsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MainMenu(),
    );
  }
}

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StockStash'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Main Menu',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CabinetsPage()),
                );
              },
              child: const Text('Go to Cabinets'),
            ),
            ElevatedButton(
              onPressed: () async {
                _readNfcTag(context);
              },
              child: const Text('Read NFC Tag'),
            ),
          ],
        ),
      ),
    );
  }

  void _readNfcTag(BuildContext context) async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('NFC is not available on this device')),
      );
      return;
    }

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          NdefMessage? message = await Ndef.from(tag)?.read();
          if (message != null && message.records.isNotEmpty) {
            NdefRecord record = message.records.first;
            String payload = String.fromCharCodes(record.payload).substring(3); // Remove language code
            print("Read NFC Tag: $payload"); // Debug print
            NfcManager.instance.stopSession();
            _openCabinetWithKey(context, payload);
          }
        } catch (e) {
          print("Error reading NFC tag: $e"); // Debug print
          NfcManager.instance.stopSession(errorMessage: 'Failed to read NFC tag');
        }
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tap an NFC tag')),
    );
  }

void _openCabinetWithKey(BuildContext context, String key) async {
  DatabaseHelper dbHelper = DatabaseHelper();
  List<Cabinet> cabinets = await dbHelper.getCabinets();
  
  print("NFC Tag Key: $key"); // Debug print
  print("All Cabinets: ${cabinets.map((c) => '${c.id}: ${c.name} (${c.data})')}"); // Debug print

  Cabinet? cabinetToOpen;
  try {
    cabinetToOpen = cabinets.firstWhere(
      (cabinet) => cabinet.data == key,
    );
  } catch (e) {
    cabinetToOpen = null;
  }

  if (cabinetToOpen != null) {
    print("Opening cabinet: ${cabinetToOpen.id}: ${cabinetToOpen.name} (${cabinetToOpen.data})"); // Debug print
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemsPage(cabinet: cabinetToOpen!),
      ),
    );
  } else {
    print("No cabinet found with key: $key"); // Debug print
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No cabinet found with this NFC tag')),
    );
  }
}
}

class CabinetsPage extends StatefulWidget {
  const CabinetsPage({super.key});

  @override
  State<CabinetsPage> createState() => _CabinetsPageState();
}

class _CabinetsPageState extends State<CabinetsPage> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  final List<Cabinet> _cabinets = [];

  @override
  void initState() {
    super.initState();
    _loadCabinets();
  }

  void _loadCabinets() async {
    List<Cabinet> cabinets = await dbHelper.getCabinets();
    setState(() {
      _cabinets.addAll(cabinets);
    });
  }

  void _addCabinet(Cabinet cabinet) async {
    final random = Random();
    String uniqueKey = '${DateTime.now().millisecondsSinceEpoch}-${random.nextInt(10000)}';
    
    Cabinet cabinetWithKey = Cabinet(0, cabinet.name, uniqueKey);
    int id = await dbHelper.insertCabinet(cabinetWithKey);
    print('Inserted cabinet with ID: $id, Unique Key: $uniqueKey');
    setState(() {
      _cabinets.add(Cabinet(id, cabinet.name, uniqueKey));
    });

    _offerNfcWrite(context, uniqueKey);
  }

  void _offerNfcWrite(BuildContext context, String key) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Write to NFC Tag'),
          content: Text('Would you like to write the cabinet key to an NFC tag?'),
          actions: <Widget>[
            TextButton(
              child: Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop();
                _writeNfcTag(context, key);
              },
            ),
          ],
        );
      },
    );
  }

  void _writeNfcTag(BuildContext context, String key) async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('NFC is not available on this device')),
      );
      return;
    }

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        var ndef = Ndef.from(tag);
        if (ndef == null) {
          NfcManager.instance.stopSession(errorMessage: 'Tag is not NDEF compatible');
          return;
        }

        NdefMessage message = NdefMessage([
          NdefRecord.createText(key),
        ]);

        try {
          await ndef.write(message);
          print("Wrote to NFC Tag: $key"); // Debug print
          NfcManager.instance.stopSession();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully wrote to NFC tag')),
          );
        } catch (e) {
          print("Error writing to NFC tag: $e"); // Debug print
          NfcManager.instance.stopSession(errorMessage: 'Failed to write to NFC tag');
        }
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tap an NFC tag to write')),
    );
  }

  void _removeCabinet(Cabinet cabinet) async {
    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${cabinet.name}?'),
        content: Text("Are you sure you want to remove, this action cannot be reverted?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, 'Cancel');
            },
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context, 'Delete');
              await dbHelper.removeCabinet(cabinet.id);
              setState(() {
                _cabinets.remove(cabinet);
              });
            },
            child: Text('Delete'),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Icon(Icons.warehouse),
        title: const Text('StockStash'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue[400]!, Colors.blue[50]!],
            ),
          ),
        ),
      ),
      body: ListView(
        children: [
          for (var cabinet in _cabinets)
            ListTile(
              title: Text(cabinet.name),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ItemsPage(cabinet: cabinet),
                  ),
                );
              },
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  _removeCabinet(cabinet);
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddCabinetDialog(
              onAdd: _addCabinet,
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class Cabinet {
  final int id;
  final String name;
  final String data;
  final List<Item> items = [];

  Cabinet(this.id, this.name, this.data);
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

  void _addItem(String name, int count) async {
    Item item = Item(0, name, count);
    int id = await dbHelper.insertItem(item, widget.cabinet.id);
    print('Added item with ID: $id, name: ${item.name}, count: ${item.count}');
    setState(() {
      widget.cabinet.items.add(Item(id, name, count));
    });
  }

  void _removeItem(Item item) async {
    await dbHelper.removeItem(item.id);
    setState(() {
      widget.cabinet.items.remove(item);
    });
  }

  void _updateItemCount(Item item, int delta) async {
    await dbHelper.updateItemCount(item, delta);
    setState(() {
      item.count += delta;
      if (item.count <= 0) {
        widget.cabinet.items.remove(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cabinet.name),
      ),
      body: ListView(
        children: [
          for (var item in widget.cabinet.items)
            ListTile(
              title: Text(item.name),
              subtitle: Text('${item.count}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      _updateItemCount(item, 1);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      _updateItemCount(item, -1);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddItemDialog(
              onAdd: _addItem,
            ),
          );
        },
        child: const Icon(Icons.add),
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