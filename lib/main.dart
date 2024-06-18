import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  static final items = <String>[];

  @override
  State<MyApp> createState() => _MyAppState();
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class _MyAppState extends State<MyApp> {
  List<String> items = [];

  void addItem(String item) {
    setState(() {
      items.add(item);
    });
  }

  void removeItem(String item) {
    setState(() {
      items.remove(item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blueAccent[100],
          title: const Text("Stock Stash"),
          actions: [
            Builder(
              builder: (context) {
                return IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {
                    showSearch(
                      context: context,
                      delegate: CustomSearchDelegate(items),
                    );
                  },
                );
              },
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: ElevatedButton(
                          onPressed: () async {
                            final name = await showDialog<String>(
                              context: context,
                              builder: (context) => const ItemNameDialog(),
                            );
                            if (name != null) {
                              addItem(name);
                            }
                          },
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ),
                    for (var entry in items.asMap().entries)
                      ItemWidget(
                        text: entry.value,
                        key: ValueKey(entry.key),
                        onRemove: () => removeItem(entry.value),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class CustomSearchDelegate extends SearchDelegate<String> {
  final List<String> items;

  CustomSearchDelegate(this.items);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, "null");
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final matchQuery = items.where((item) {
      return item.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: matchQuery.length,
      itemBuilder: (context, index) {
        final item = matchQuery[index];
        return ListTile(
          title: Text(item),
          onTap: () {
            close(context, item);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final matchQuery = items.where((item) {
      return item.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: matchQuery.length,
      itemBuilder: (context, index) {
        final item = matchQuery[index];
        return ListTile(
          title: Text(item),
          onTap: () {
            query = item;
            showResults(context);
          },
        );
      },
    );
  }
}

class ItemNameDialog extends StatefulWidget {
  const ItemNameDialog({Key? key}) : super(key: key);

  @override
  State<ItemNameDialog> createState() => _ItemNameDialogState();
}

class _ItemNameDialogState extends State<ItemNameDialog> {
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Item Name'),
      content: TextField(
        controller: _nameController,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context, _nameController.text);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

class ItemWidget extends StatefulWidget {
  const ItemWidget({
    Key? key,
    required this.text,
    required this.onRemove,
  }) : super(key: key);

  final String text;
  final VoidCallback onRemove;

  @override
  State<ItemWidget> createState() => _ItemWidgetState();
}

class _ItemWidgetState extends State<ItemWidget> {
  int _count = 1;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 100,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              flex: 3,
              fit: FlexFit.tight,
              child: Container(
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  widget.text,
                  style: const TextStyle(color: Colors.pink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Spacer(),
            Flexible(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: TextField(
                      textAlign: TextAlign.center,
                      controller: TextEditingController(text: '$_count'),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (value) {
                        final newCount = int.tryParse(value) ?? _count;
                        if (newCount == 0) {
                          widget.onRemove();
                        } else {
                          setState(() {
                            _count = newCount;
                          });
                        }
                      },
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => setState(() => _count++),
                        child: const Text('+'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (_count > 1) {
                            setState(() => _count--);
                          } else {
                            widget.onRemove();
                          }
                        },
                        child: const Text('-'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
