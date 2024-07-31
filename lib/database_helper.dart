import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'main.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();
  
  static Database? _database;

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
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _upgradeTables(db, oldVersion, newVersion);
      },
      version: 4,
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE cabinets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        data TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        count INTEGER,
        cabinet_id INTEGER,
        FOREIGN KEY (cabinet_id) REFERENCES cabinets (id)
      )
    ''');
  }

  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      // Check if 'data' column exists
      var columns = await db.rawQuery('PRAGMA table_info(cabinets)');
      bool dataColumnExists = columns.any((column) => column['name'] == 'data');
      
      if (!dataColumnExists) {
        await db.execute('ALTER TABLE cabinets ADD COLUMN data TEXT');
      }
    }
  }

  Future<int> insertCabinet(Cabinet cabinet) async {
    try {
      final db = await database;
      return await db.insert('cabinets', {
        'name': cabinet.name,
        'data': cabinet.data,
      });
    } catch (e) {
      print('Error inserting cabinet: $e');
      rethrow;
    }
  }

  Future<int> insertItem(Item item, int cabinetId) async {
    final db = await database;
    return await db.insert('items', {
      'name': item.name,
      'count': item.count,
      'cabinet_id': cabinetId,
    });
  }

  Future<List<Cabinet>> getCabinets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('cabinets');

    List<Cabinet> cabinets = [];
    for (var map in maps) {
      List<Map<String, dynamic>> itemMaps = await db.query(
        'items',
        where: 'cabinet_id = ?',
        whereArgs: [map['id']],
      );
      List<Item> items = itemMaps
          .map((itemMap) => Item(itemMap['id'], itemMap['name'], itemMap['count']))
          .toList();
      Cabinet cabinet = Cabinet(map['id'], map['name'], map['data'] ?? '');
      cabinet.items.addAll(items);
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
      return await db.update(
        'items',
        {'count': newCount},
        where: 'id = ?',
        whereArgs: [item.id],
      );
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