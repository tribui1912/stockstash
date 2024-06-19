import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'main.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();
  
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'cabinets.db');
    return openDatabase(
      path,
      onCreate: (db, version) async {
        await db.execute(
          '''
          CREATE TABLE cabinets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT
          )
          '''
        );
        await db.execute(
          '''
          CREATE TABLE items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            count INTEGER,
            cabinet_id INTEGER,
            FOREIGN KEY (cabinet_id) REFERENCES cabinets (id)
          )
          '''
        );
      },
      version: 1,
    );
  }

  Future<int> insertCabinet(Cabinet cabinet) async {
    final db = await database;
    return await db.insert('cabinets', {'name': cabinet.name});
  }

  Future<int> insertItem(Item item, int cabinetId) async {
    final db = await database;
    return await db.insert('items', {'name': item.name, 'count': item.count, 'cabinet_id': cabinetId});
  }

  Future<List<Cabinet>> getCabinets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('cabinets');

    List<Cabinet> cabinets = [];
    for (var map in maps) {
      List<Map<String, dynamic>> itemMaps = await db.query('items', where: 'cabinet_id = ?', whereArgs: [map['id']]);
      List<Item> items = itemMaps.map((itemMap) => Item(itemMap['id'], itemMap['name'], itemMap['count'])).toList();
      Cabinet cabinet = Cabinet(map['id'], map['name'])..items.addAll(items);
      cabinets.add(cabinet);
    }
    return cabinets;
  }

  Future<int> updateItemCount(Item item, int delta) async {
    final db = await database;
    int newCount = item.count + delta;
    if (newCount <= 0) {
      return await db.delete('items', where: 'id = ?', whereArgs: [item.id]);
    } else {
      return await db.update('items', {'count': newCount}, where: 'id = ?', whereArgs: [item.id]);
    }
  }

  Future<int> removeCabinet(int id) async {
    final db = await database;
    await db.delete('items', where: 'cabinet_id = ?', whereArgs: [id]);
    return await db.delete('cabinets', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> removeItem(int id) async {
    final db = await database;
    return await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }
}
