import 'package:flutter/cupertino.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../models/cabinet.dart';

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
            onPressed: addCabinetWithoutNFC,
            child: Text('Add without NFC'),
          ),
      ],
    );
  }
}
