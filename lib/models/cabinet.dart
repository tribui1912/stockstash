import 'item.dart';

class Cabinet {
  final int id;
  final String name;
  final String data;
  final List<Item> items;

  Cabinet(this.id, this.name, this.data, {List<Item>? items}) : items = items ?? [];
}
