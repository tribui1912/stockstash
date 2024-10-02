import 'package:flutter/cupertino.dart';
import 'database_helper.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'dart:async';

void main() {
  runApp(const CabinetsApp());
}

class CabinetsApp extends StatelessWidget {
  const CabinetsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.activeBlue,
        scaffoldBackgroundColor: CupertinoColors.systemBackground,
      ),
      home: MainMenu(),
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
    DatabaseHelper dbHelper = DatabaseHelper();
    List<Cabinet> cabinets = await dbHelper.getCabinets();
    
    Cabinet? cabinetToOpen = cabinets.firstWhere(
      (cabinet) => cabinet.data == key,
      orElse: () => Cabinet(-1, '', ''), // Return a dummy cabinet if not found
    );

    if (!mounted) return;

    if (cabinetToOpen.id != -1) {
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => ItemsPage(cabinet: cabinetToOpen),
        ),
      );
    } else {
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
                  child: Text(_nfcActive ? 'NFC Active' : 'Activate NFC'),
                  onPressed: toggleNfc,
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

class CabinetsPage extends StatefulWidget {
  const CabinetsPage({super.key});

  @override
  State<CabinetsPage> createState() => _CabinetsPageState();
}

class _CabinetsPageState extends State<CabinetsPage> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<Cabinet> _cabinets = [];
  List<Cabinet> _filteredCabinets = [];
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCabinets();
    _searchController.addListener(_filterCabinets);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadCabinets() async {
    List<Cabinet> cabinets = await dbHelper.getCabinets();
    setState(() {
      _cabinets = cabinets;
      _filteredCabinets = cabinets;
    });
  }

  void _filterCabinets() {
    String searchTerm = _searchController.text.toLowerCase();
    setState(() {
      _filteredCabinets = _cabinets
          .where((cabinet) => cabinet.name.toLowerCase().contains(searchTerm))
          .toList();
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
    return showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text('Remove Cabinet'),
          content: Text('Are you sure you want to remove "${cabinet.name}"? This action cannot be undone.'),
          actions: <Widget>[
            CupertinoDialogAction(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
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
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Cabinets'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(CupertinoIcons.add),
          onPressed: () {
            showCupertinoDialog(
              context: context,
              builder: (context) => AddCabinetDialog(onAdd: _addCabinet),
            );
          },
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search cabinets',
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _filteredCabinets.length,
                itemBuilder: (context, index) {
                  var cabinet = _filteredCabinets[index];
                  return CabinetTile(
                    cabinet: cabinet,
                    onTap: () {
                      Navigator.push(
                        context,
                        ZoomPageRoute(
                          page: ItemsPage(cabinet: cabinet),
                        ),
                      ).then((_) => _loadCabinets());
                    },
                    onLongPress: () => _showRemoveConfirmationDialog(context, cabinet),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Create a separate stateless widget for cabinet tiles
class CabinetTile extends StatelessWidget {
  final Cabinet cabinet;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const CabinetTile({Key? key, required this.cabinet, required this.onTap, required this.onLongPress}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.2),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: CupertinoButton(
          onPressed: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.archivebox, size: 48, color: CupertinoColors.activeBlue),
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
  late List<Item> _filteredItems;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.cabinet.items);
    _filteredItems = _items;
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    String searchTerm = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = _items
          .where((item) => item.name.toLowerCase().contains(searchTerm))
          .toList();
    });
  }

  void _addItem(String name, int count) async {
    Item newItem = Item(0, name, count);
    int id = await dbHelper.insertItem(newItem, widget.cabinet.id);
    setState(() {
      _items.add(Item(id, name, count));
      _filterItems();
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
    return showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text('Remove Item'),
          content: Text('Are you sure you want to remove "${item.name}"? This action cannot be undone.'),
          actions: <Widget>[
            CupertinoDialogAction(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
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
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.cabinet.name),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(CupertinoIcons.add),
          onPressed: () {
            showCupertinoDialog(
              context: context,
              builder: (context) => AddItemDialog(onAdd: _addItem),
            );
          },
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search items',
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: _filteredItems.length,
                separatorBuilder: (context, index) => Container(
                  height: 1,
                  color: CupertinoColors.separator,
                ),
                itemBuilder: (context, index) {
                  var item = _filteredItems[index];
                  return ItemTile(item: item, onUpdate: _updateItemCount, onRemove: _removeItem);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Create a separate stateless widget for item tiles
class ItemTile extends StatelessWidget {
  final Item item;
  final Function(Item, int) onUpdate;
  final Function(Item) onRemove;

  const ItemTile({Key? key, required this.item, required this.onUpdate, required this.onRemove}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => onRemove(item),
      child: Dismissible(
        key: Key(item.id.toString()),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          return await showCupertinoDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return CupertinoAlertDialog(
                title: Text('Delete Item'),
                content: Text('Are you sure you want to delete "${item.name}"?'),
                actions: <Widget>[
                  CupertinoDialogAction(
                    child: Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    child: Text('Delete'),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              );
            },
          ) ?? false;
        },
        onDismissed: (direction) {
          onRemove(item);
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20.0),
          color: CupertinoColors.destructiveRed,
          child: Icon(CupertinoIcons.delete, color: CupertinoColors.white),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Quantity: ${item.count}',
                      style: TextStyle(fontSize: 16, color: CupertinoColors.secondaryLabel),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(CupertinoIcons.minus_circle, color: CupertinoColors.destructiveRed),
                onPressed: () => onUpdate(item, -1),
              ),
              SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(CupertinoIcons.plus_circle, color: CupertinoColors.activeGreen),
                onPressed: () => onUpdate(item, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddCabinetDialog extends StatefulWidget {
  final Function(Cabinet) onAdd;

  const AddCabinetDialog({super.key, required this.onAdd});

  @override
  State<AddCabinetDialog> createState() => _AddCabinetDialogState();
}

class _AddCabinetDialogState extends State<AddCabinetDialog> {
  final TextEditingController nameController = TextEditingController();
  bool isWritingNFC = false;
  String nfcStatus = '';

  Future<void> writeNFC(String cabinetName) async {
    setState(() {
      isWritingNFC = true;
      nfcStatus = 'Tap an NFC tag to write...';
    });

    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        throw 'NFC not available on this device.';
      }

      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          var ndef = Ndef.from(tag);
          if (ndef == null) {
            throw 'Tag is not NDEF compatible.';
          }

          if (!ndef.isWritable) {
            throw 'Tag is not writable.';
          }

          NdefMessage message = NdefMessage([
            NdefRecord.createText(cabinetName),
          ]);

          try {
            if (!mounted) return;
            setState(() {
              nfcStatus = 'Writing to NFC tag...';
            });
            await ndef.write(message);
            if (!mounted) return;
            setState(() {
              nfcStatus = 'Successfully written to NFC tag!';
            });
            // Successfully written, now add the cabinet
            String nfcData = cabinetName; // You might want to use a more unique identifier
            widget.onAdd(Cabinet(0, cabinetName, nfcData));
            await Future.delayed(Duration(seconds: 1)); // Show success message briefly
            if (!mounted) return;
            Navigator.of(context).pop();
          } catch (e) {
            throw 'Failed to write to tag: $e';
          } finally {
            NfcManager.instance.stopSession();
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        nfcStatus = 'Error: ${e.toString()}';
        isWritingNFC = false;
      });
    }
  }

  void addCabinetWithoutNFC() {
    if (nameController.text.isNotEmpty) {
      widget.onAdd(Cabinet(0, nameController.text, ''));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text('Add Cabinet'),
      content: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: CupertinoTextField(
              controller: nameController,
              placeholder: 'Cabinet Name',
              autofocus: true,
            ),
          ),
          if (isWritingNFC) 
            Column(
              children: [
                CupertinoActivityIndicator(),
                SizedBox(height: 8),
                Text(nfcStatus),
              ],
            ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          child: Text('Cancel'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        if (!isWritingNFC)
          CupertinoDialogAction(
            child: Text('Add with NFC'),
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                writeNFC(nameController.text);
              }
            },
          ),
        if (!isWritingNFC)
          CupertinoDialogAction(
            child: Text('Add without NFC'),
            onPressed: addCabinetWithoutNFC,
          ),
      ],
    );
  }
}

class AddItemDialog extends StatefulWidget {
  final Function(String, int) onAdd;

  const AddItemDialog({super.key, required this.onAdd});

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController countController = TextEditingController(text: '1');

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text('Add Item'),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          children: [
            CupertinoTextField(
              controller: nameController,
              placeholder: 'Item Name',
              autofocus: true,
            ),
            SizedBox(height: 8),
            CupertinoTextField(
              controller: countController,
              placeholder: 'Count',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          child: Text('Cancel'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        CupertinoDialogAction(
          child: Text('Add'),
          onPressed: () {
            if (nameController.text.isNotEmpty && countController.text.isNotEmpty) {
              widget.onAdd(nameController.text, int.parse(countController.text));
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }
}

class ZoomPageRoute extends PageRouteBuilder {
  final Widget page;

  ZoomPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var begin = 0.0;
            var end = 1.0;
            var curve = Curves.ease;

            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var scaleAnimation = animation.drive(tween);

            return ScaleTransition(
              scale: scaleAnimation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
        );
}