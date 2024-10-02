import 'package:flutter/cupertino.dart';
import '../models/item.dart';

class ItemTile extends StatelessWidget {
  final Item item;
  final Function(Item, int) onUpdate;
  final Function(Item) onRemove;

  const ItemTile({super.key, required this.item, required this.onUpdate, required this.onRemove});

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

