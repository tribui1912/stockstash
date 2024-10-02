import 'package:flutter/cupertino.dart';
import '../models/cabinet.dart';
import '../utils/database_helper.dart';
import '../widgets/cabinet_tile.dart';
import '../widgets/add_cabinet_dialog.dart';
import '../utils/zoom_page_route.dart';
import 'items_page.dart';

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
