import 'package:flutter/material.dart';

void main() {
  runApp(const CabinetsApp());
}

class CabinetsApp extends StatelessWidget {
  const CabinetsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const CabinetsPage(),
    );
  }
}

class CabinetsPage extends StatefulWidget {
  const CabinetsPage({super.key});

  @override
  State<CabinetsPage> createState() => _CabinetsPageState();
}

class _CabinetsPageState extends State<CabinetsPage> {
  final List<Cabinet> _cabinets = [];

  void _addCabinet(Cabinet cabinet) {
    setState(() {
      _cabinets.add(cabinet);
    });
  }

  void _removeCabinet(Cabinet cabinet) {
    setState(() {
      _cabinets.remove(cabinet);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StockStash'),
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
  final String name;
  final List<Item> items = [];

  Cabinet(this.name);
}

class Item {
  final String name;
  int count;

  Item(this.name, this.count);
}

class ItemsPage extends StatefulWidget {
  final Cabinet cabinet;

  const ItemsPage({super.key, required this.cabinet});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  void _addItem(String name, int count) {
    setState(() {
      widget.cabinet.items.add(Item(name, count));
    });
  }

  void _removeItem(Item item) {
    setState(() {
      widget.cabinet.items.remove(item);
    });
  }

  void _updateItemCount(Item item, int delta) {
    setState(() {
      item.count += delta;
      if (item.count <= 0) {
        _removeItem(item);
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
              subtitle: Text('$item.count'),
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
            onAdd(Cabinet(nameController.text));
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
