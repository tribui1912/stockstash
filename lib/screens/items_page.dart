import 'package:flutter/cupertino.dart';
import '../models/cabinet.dart';
import '../models/item.dart';
import '../utils/database_helper.dart';
import '../widgets/item_tile.dart';
import '../widgets/add_item_dialog.dart';

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
    _filterItems();
  }

  void _removeItem(Item item) async {
    await dbHelper.removeItem(item.id);
    setState(() {
      _items.remove(item);
      _filterItems();
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
                  return ItemTile(
                    item: item,
                    onUpdate: _updateItemCount,
                    onRemove: (item) => _showRemoveConfirmationDialog(context, item),
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

