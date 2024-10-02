import 'package:flutter/cupertino.dart';
import '../models/cabinet.dart';

class CabinetTile extends StatelessWidget {
  final Cabinet cabinet;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const CabinetTile({super.key, required this.cabinet, required this.onTap, required this.onLongPress});

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