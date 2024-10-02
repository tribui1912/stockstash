import 'package:flutter/cupertino.dart';

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

