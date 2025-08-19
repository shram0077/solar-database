import 'package:intl/intl.dart';
import 'package:solar_database/screens/Hawala/hawala.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:developer' as developer;

class DatabaseHelper {
  static const String _databaseName = 'solar_inventory.db';
  static const int _databaseVersion = 15;

  static const String tableCompanies = 'companies';
  static const String tableItems = 'items';
  static const String tableSales = 'sales';
  static const String tableDebts = 'debts';
  static const String tableExpenses = 'expenses';
  static const String tableHawalas = 'hawalas';

  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;

  DatabaseHelper._internal();

  final StreamController<void> _dataChangeController =
      StreamController.broadcast();
  Stream<void> get onDataChanged => _dataChangeController.stream;

  void notifyDataChanged() {
    if (!_dataChangeController.isClosed) {
      _dataChangeController.add(null);
    }
  }

  static const Map<String, String> columns = {
    'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
    'item_name': 'TEXT NOT NULL',
    'category': 'TEXT NOT NULL',
    'buying_price': 'REAL NOT NULL',
    'selling_price': 'REAL NOT NULL',
    'buying_price_retail': 'REAL NOT NULL DEFAULT 0.0',
    'selling_price_retail': 'REAL NOT NULL DEFAULT 0.0',
    'quantity': 'INTEGER NOT NULL DEFAULT 0',
    'supplier': 'TEXT',
    'purchase_date': 'TEXT',
    'brand': 'TEXT',
    'model': 'TEXT',
    'power': 'TEXT',
    'voltage': 'TEXT',
    'origin_country': 'TEXT',
    'warranty': 'TEXT',
    'notes': 'TEXT',
    'is_currency_usd': 'BOOLEAN DEFAULT false',
    'isPaidCash': 'BOOLEAN DEFAULT true',
    'created_at': 'TEXT DEFAULT CURRENT_TIMESTAMP',
    'updated_at': 'TEXT DEFAULT CURRENT_TIMESTAMP',
    'barcode': 'TEXT UNIQUE',
    'debt_price': 'REAL NOT NULL DEFAULT 0.0',
  };

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, _databaseName);

      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('PRAGMA journal_mode = WAL');
        },
      );
    } catch (e) {
      developer.log('Database initialization failed', error: e);
      rethrow;
    }
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE $tableCompanies (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          company_name TEXT NOT NULL,
          company_type TEXT NOT NULL,
          contact_person TEXT NOT NULL,
          phone TEXT NOT NULL,
          email TEXT,
          address TEXT,
          city TEXT,
          country TEXT,
          tax_number TEXT,
          registration_number TEXT,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT
        )
      ''');

      final columnsDefinition = columns.entries
          .map((e) => '${e.key} ${e.value}')
          .join(', ');
      await txn.execute('CREATE TABLE $tableItems ($columnsDefinition)');

      await txn.execute('''
      CREATE TABLE $tableSales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id TEXT NOT NULL,
        item_name TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        customer_phone TEXT,
        customer_address TEXT,
        quantity INTEGER NOT NULL,
        selling_price REAL NOT NULL,
        selling_price_usd REAL NOT NULL DEFAULT 0.0,
        buying_price REAL NOT NULL,
        buying_price_usd REAL NOT NULL DEFAULT 0.0,
        discount REAL DEFAULT 0,
        discount_usd REAL DEFAULT 0.0,
        total_amount REAL NOT NULL,
        total_amount_usd REAL NOT NULL DEFAULT 0.0,
        final_amount REAL NOT NULL,
        final_amount_usd REAL NOT NULL DEFAULT 0.0,
        profit REAL NOT NULL,
        profit_iqd REAL NOT NULL DEFAULT 0.0,
        warranty TEXT,
        warranty_months INTEGER DEFAULT 0,
        warranty_price REAL DEFAULT 0.0,
        payment_method TEXT NOT NULL,
        notes TEXT,
        sale_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        currency TEXT,
        exchange_rate REAL,
        FOREIGN KEY(item_id) REFERENCES $tableItems(barcode) ON DELETE RESTRICT
      )
    ''');

      // NEW: Create Debts Table
      await txn.execute('''
        CREATE TABLE $tableDebts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_name TEXT NOT NULL,
          customer_address TEXT,
          customer_phone TEXT,
          total_amount REAL NOT NULL,
          paid_amount REAL NOT NULL DEFAULT 0.0,
          debt_amount REAL NOT NULL,
          sale_date TEXT NOT NULL,
          currency TEXT NOT NULL,
          exchange_rate REAL NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT
        )
      ''');

      await txn.execute('''
  CREATE TABLE $tableExpenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    amount REAL NOT NULL,
    notes TEXT,
    date TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
  )
''');
      await txn.execute('''
  CREATE TABLE $tableHawalas (
    id TEXT PRIMARY KEY,
    company_id INTEGER,
    company_name TEXT NOT NULL,
    company_type TEXT NOT NULL,
    amount REAL NOT NULL,
    currency TEXT NOT NULL,
    date INTEGER NOT NULL,
    notes TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    is_sent INTEGER NOT NULL DEFAULT 1,
    sender_name TEXT,
    receiver_name TEXT,
    FOREIGN KEY(company_id) REFERENCES $tableCompanies(id) ON DELETE SET NULL
  )
''');
    });
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    developer.log('Upgrading database from $oldVersion to $newVersion');

    if (oldVersion < 9) {
      await db.execute(
        'ALTER TABLE $tableItems ADD COLUMN buying_price_retail REAL NOT NULL DEFAULT 0.0',
      );
      await db.execute(
        'ALTER TABLE $tableItems ADD COLUMN selling_price_retail REAL NOT NULL DEFAULT 0.0',
      );
    }

    if (oldVersion < 10) {
      await db.execute(
        'ALTER TABLE $tableSales ADD COLUMN debt_price REAL NOT NULL DEFAULT 0.0',
      );
    }

    if (oldVersion < 11) {
      await db.execute('ALTER TABLE $tableSales ADD COLUMN warranty TEXT');
    }

    if (oldVersion < 12) {
      await db.execute(
        'ALTER TABLE $tableSales ADD COLUMN selling_price_usd REAL NOT NULL DEFAULT 0.0',
      );
      await db.execute(
        'ALTER TABLE $tableSales ADD COLUMN buying_price_usd REAL NOT NULL DEFAULT 0.0',
      );
      await db.execute(
        'ALTER TABLE $tableSales ADD COLUMN discount_usd REAL NOT NULL DEFAULT 0.0',
      );
      await db.execute(
        'ALTER TABLE $tableSales ADD COLUMN total_amount_usd REAL NOT NULL DEFAULT 0.0',
      );
      await db.execute(
        'ALTER TABLE $tableSales ADD COLUMN final_amount_usd REAL NOT NULL DEFAULT 0.0',
      );
      await db.execute(
        'ALTER TABLE $tableSales ADD COLUMN profit_iqd REAL NOT NULL DEFAULT 0.0',
      );
      await db.execute('ALTER TABLE $tableSales ADD COLUMN currency TEXT');
      await db.execute('ALTER TABLE $tableSales ADD COLUMN exchange_rate REAL');

      await db.execute('''
        CREATE TABLE $tableDebts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_name TEXT NOT NULL,
          customer_phone TEXT,
          customer_address TEXT,
          total_amount REAL NOT NULL,
          paid_amount REAL NOT NULL DEFAULT 0.0,
          debt_amount REAL NOT NULL,
          sale_date TEXT NOT NULL,
          currency TEXT NOT NULL,
          exchange_rate REAL NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT
        )
      ''');
    }

    if (oldVersion < 13) {
      await db.execute('''
        CREATE TABLE $tableExpenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount REAL NOT NULL,
          notes TEXT,
          date TEXT NOT NULL,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
    }

    if (oldVersion < 14) {
      await db.execute('''
        CREATE TABLE $tableHawalas (
          id TEXT PRIMARY KEY,
          company_id INTEGER,
          company_name TEXT NOT NULL,
          company_type TEXT NOT NULL,
          amount REAL NOT NULL,
          currency TEXT NOT NULL,
          date INTEGER NOT NULL,
          notes TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY(company_id) REFERENCES $tableCompanies(id) ON DELETE SET NULL
        )
      ''');
      await db.execute(
        'ALTER TABLE $tableSales ADD COLUMN warranty_months INTEGER',
      );
      await db.execute(
        'ALTER TABLE $tableSales ADD COLUMN warranty_price REAL',
      );
    }

    if (oldVersion < 15) {
      // For version 15, we need to alter the hawalas table to add the new columns
      await db.execute(
        'ALTER TABLE $tableHawalas ADD COLUMN is_sent INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute('ALTER TABLE $tableHawalas ADD COLUMN sender_name TEXT');
      await db.execute(
        'ALTER TABLE $tableHawalas ADD COLUMN receiver_name TEXT',
      );
    }
  }

  Future<int> insertExpense(Map<String, dynamic> expense) async {
    final db = await database;
    try {
      final result = await db.insert(tableExpenses, {
        'amount': expense['amount'],
        'notes': expense['notes'],
        'date': expense['date'].toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
      notifyDataChanged();
      return result;
    } catch (e) {
      developer.log('Error inserting expense', error: e);
      rethrow;
    }
  }

  Future<int> insertHawalaTransaction(HawalaTransaction transaction) async {
    final db = await database;
    try {
      final result = await db.insert(
        tableHawalas,
        transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      notifyDataChanged();
      return result;
    } catch (e) {
      developer.log('Error inserting hawala transaction', error: e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllHawalaTransactions() async {
    final db = await database;
    // Order transactions by date in descending order (most recent first)
    return await db.query(tableHawalas, orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> getAllExpenses() async {
    final db = await database;
    try {
      return await db.query(tableExpenses, orderBy: 'date DESC');
    } catch (e) {
      developer.log('Error fetching expenses', error: e);
      rethrow;
    }
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    try {
      final result = await db.delete(
        tableExpenses,
        where: 'id = ?',
        whereArgs: [id],
      );
      notifyDataChanged();
      return result;
    } catch (e) {
      developer.log('Error deleting expense', error: e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> searchExpenses(String query) async {
    final db = await database;
    try {
      return await db.query(
        tableExpenses,
        where: 'notes LIKE ? OR amount LIKE ? OR date LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
        orderBy: 'date DESC',
      );
    } catch (e) {
      developer.log('Error searching expenses', error: e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCustomerPayments(
    String customerName,
    String? customerPhone,
  ) async {
    final db = await database;
    final where = customerPhone != null
        ? 'customer_name = ? AND customer_phone = ?'
        : 'customer_name = ?';
    final whereArgs = customerPhone != null
        ? [customerName, customerPhone]
        : [customerName];

    return await db.query(
      'sales', // or your payments table name
      where: where,
      whereArgs: whereArgs,
      orderBy: 'sale_date DESC',
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    final result = await db.delete(
      tableItems,
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyDataChanged();
    return result;
  }

  Future<int> insertItem(Map<String, dynamic> item) async {
    final db = await database;
    try {
      final validatedItem = _validateAndTransformItem(item);
      final now = DateTime.now().toIso8601String();
      validatedItem['created_at'] ??= now;
      validatedItem['updated_at'] ??= now;

      final result = await db.insert(
        tableItems,
        validatedItem,
        conflictAlgorithm: ConflictAlgorithm.rollback,
      );
      notifyDataChanged();
      return result;
    } catch (e) {
      developer.log('Insert failed: ${e.toString()}', error: e);
      throw Exception('Failed to insert item: ${e.toString()}');
    }
  }

  Future<int> getItemQuantity(String barcode) async {
    final db = await database;
    final results = await db.query(
      tableItems,
      columns: ['quantity'],
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return results.first['quantity'] as int? ?? 0;
    }
    return 0;
  }

  Future<List<Map<String, dynamic>>> getAllItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'items',
      where: 'quantity > 0',
    );
    return maps;
  }

  Future<int> updateItem(Map<String, dynamic> item) async {
    final db = await database;
    if (item['id'] == null) {
      throw ArgumentError('Item must have an ID to be updated');
    }

    final validatedItem = _validateAndTransformItem(item);
    validatedItem['updated_at'] = DateTime.now().toIso8601String();

    final result = await db.update(
      tableItems,
      validatedItem,
      where: 'id = ?',
      whereArgs: [item['id']],
    );
    notifyDataChanged();
    return result;
  }

  Map<String, dynamic> _validateAndTransformItem(Map<String, dynamic> item) {
    if (item['item_name'] == null ||
        item['item_name'].toString().trim().isEmpty) {
      throw ArgumentError('Item name is required');
    }
    if (item['category'] == null ||
        item['category'].toString().trim().isEmpty) {
      throw ArgumentError('Category is required');
    }

    final transformed = Map<String, dynamic>.from(item);

    transformed['item_name'] = transformed['item_name'].toString().trim();
    transformed['category'] = transformed['category'].toString().trim();

    transformed['quantity'] =
        int.tryParse(transformed['quantity']?.toString() ?? '') ?? 0;
    transformed['buying_price'] =
        double.tryParse(transformed['buying_price']?.toString() ?? '') ?? 0.0;
    transformed['selling_price'] =
        double.tryParse(transformed['selling_price']?.toString() ?? '') ?? 0.0;
    transformed['buying_price_retail'] =
        double.tryParse(transformed['buying_price_retail']?.toString() ?? '') ??
        0.0;
    transformed['selling_price_retail'] =
        double.tryParse(
          transformed['selling_price_retail']?.toString() ?? '',
        ) ??
        0.0;

    if (transformed['purchase_date'] is DateTime) {
      transformed['purchase_date'] = DateFormat(
        'yyyy-MM-dd',
      ).format(transformed['purchase_date']);
    }

    return transformed;
  }

  Future<int> get count async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM $tableItems');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> insertCompany(Map<String, dynamic> row) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final newRow = Map<String, dynamic>.from(row);
    newRow['created_at'] ??= now;
    newRow['updated_at'] ??= now;

    final id = await db.insert(tableCompanies, newRow);
    notifyDataChanged();
    return id;
  }

  Future<int> updateCompany(Map<String, dynamic> row) async {
    final db = await database;
    if (row['id'] == null) {
      throw ArgumentError('Company must have an ID to be updated');
    }

    final newRow = Map<String, dynamic>.from(row);
    newRow['updated_at'] = DateTime.now().toIso8601String();

    final result = await db.update(
      tableCompanies,
      newRow,
      where: 'id = ?',
      whereArgs: [row['id']],
    );
    notifyDataChanged();
    return result;
  }

  // In DatabaseHelper class
  Future<int> deleteHawalaTransaction(String id) async {
    final db = await database;
    try {
      final result = await db.delete(
        tableHawalas,
        where: 'id = ?',
        whereArgs: [id],
      );
      notifyDataChanged();
      return result;
    } catch (e) {
      developer.log('Error deleting hawala transaction', error: e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllSales() async {
    final db = await database;

    try {
      final List<Map<String, dynamic>> salesRecords = await db.query(
        tableSales,
        columns: [
          'id',
          'item_id',
          'item_name',
          'customer_name',
          'customer_phone',
          'customer_address',
          'quantity',
          'selling_price',
          'selling_price_usd',
          'buying_price',
          'buying_price_usd',
          'discount',
          'discount_usd',
          'total_amount',
          'total_amount_usd',
          'final_amount',
          'final_amount_usd',
          'profit',
          'profit_iqd',
          'payment_method',
          'notes',
          'sale_date',
          'created_at',
          'currency',
          'exchange_rate',
          'warranty',
          'warranty_months',
          'warranty_price',
        ],
        orderBy: 'sale_date DESC',
      );

      return salesRecords;
    } catch (e) {
      developer.log("Error fetching sales data", error: e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> searchHawalaTransactions(
    String query,
  ) async {
    final db = await database;
    try {
      return await db.query(
        tableHawalas,
        where:
            'company_name LIKE ? OR notes LIKE ? OR amount LIKE ? OR sender_name LIKE ? OR receiver_name LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%', '%$query%'],
        orderBy: 'date DESC',
      );
    } catch (e) {
      developer.log('Error searching hawala transactions', error: e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllCompanies() async {
    final db = await database;
    return await db.query(tableCompanies, orderBy: 'company_name ASC');
  }

  Future<List<Map<String, dynamic>>> getCompaniesByType(String type) async {
    final db = await database;
    return await db.query(
      tableCompanies,
      where: 'company_type = ?',
      whereArgs: [type],
      orderBy: 'company_name ASC',
    );
  }

  Future<Map<String, dynamic>?> getCompany(int id) async {
    final db = await database;
    final maps = await db.query(
      tableCompanies,
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isEmpty ? null : maps.first;
  }

  Future<int> deleteCompany(int id) async {
    final db = await database;
    final result = await db.delete(
      tableCompanies,
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyDataChanged();
    return result;
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> dispose() async {
    await close();
    if (!_dataChangeController.isClosed) {
      await _dataChangeController.close();
    }
  }

  Future<Map<String, dynamic>?> getItemByBarcode(String barcode) async {
    final db = await database;
    try {
      final results = await db.query(
        tableItems,
        where: 'barcode = ?',
        whereArgs: [barcode],
        limit: 1,
      );
      return results.isEmpty ? null : results.first;
    } catch (e) {
      developer.log('Error getting item by barcode', error: e);
      rethrow;
    }
  }

  Future<int> updateItemQuantity(String barcode, int newQuantity) async {
    final db = await database;
    try {
      final result = await db.update(
        tableItems,
        {
          'quantity': newQuantity,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'barcode = ?',
        whereArgs: [barcode],
      );
      notifyDataChanged();
      return result;
    } catch (e) {
      developer.log('Error updating item quantity', error: e);
      rethrow;
    }
  }

  Future<int> updateItemQuantityWithCheck(
    String barcode,
    int currentQuantity,
    int soldQuantity,
  ) async {
    final db = await database;
    try {
      final result = await db.transaction<int>((txn) async {
        final results = await txn.query(
          tableItems,
          columns: ['quantity'],
          where: 'barcode = ?',
          whereArgs: [barcode],
          limit: 1,
        );

        if (results.isEmpty) {
          throw Exception('Item not found with barcode: $barcode');
        }

        final dbQuantity = results.first['quantity'] as int? ?? 0;

        if (dbQuantity != currentQuantity) {
          throw Exception(
            'Item quantity has changed since last check. Expected: $currentQuantity, Actual: $dbQuantity',
          );
        }

        final newQuantity = dbQuantity - soldQuantity;

        final updateResult = await txn.update(
          tableItems,
          {
            'quantity': newQuantity,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'barcode = ?',
          whereArgs: [barcode],
        );

        return updateResult;
      });

      notifyDataChanged();
      return result ?? 0;
    } catch (e) {
      developer.log('Error updating item quantity with check', error: e);
      rethrow;
    }
  }

  Future<bool> hasSales(String barcode) async {
    final db = await database;
    try {
      final result = await db.query(
        tableSales,
        columns: ['id'],
        where: 'item_id = ?',
        whereArgs: [barcode],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      developer.log('Error checking for sales', error: e);
      rethrow;
    }
  }

  Future<int> addSale(Map<String, dynamic> saleData) async {
    final db = await database;
    try {
      final validatedSale = Map<String, dynamic>.from(saleData);
      validatedSale['created_at'] ??= DateTime.now().toIso8601String();
      validatedSale['warranty_months'] ??= 0;
      validatedSale['warranty_price'] ??= 0.0;

      final result = await db.insert(
        tableSales,
        validatedSale,
        conflictAlgorithm: ConflictAlgorithm.rollback,
      );
      notifyDataChanged();
      return result;
    } catch (e) {
      developer.log('Error adding sale', error: e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllSoldItems({
    int? limit,
    int? offset,
    String? orderBy,
    bool descending = true,
  }) async {
    final db = await database;
    try {
      return await db.query(
        tableSales,
        limit: limit,
        offset: offset,
        orderBy: orderBy ?? 'sale_date ${descending ? 'DESC' : 'ASC'}',
      );
    } catch (e) {
      developer.log('Error fetching sold items', error: e);
      throw Exception('Failed to fetch sold items: ${e.toString()}');
    }
  }

  Future<void> deleteSale(int saleId) async {
    final db = await database;
    await db.transaction((txn) async {
      final saleDetailsList = await txn.query(
        tableSales,
        where: 'id = ?',
        whereArgs: [saleId],
        limit: 1,
      );

      if (saleDetailsList.isEmpty) {
        developer.log('Sale with ID $saleId not found for deletion.');
        return;
      }
      final saleDetails = saleDetailsList.first;
      final barcode = saleDetails['item_id'] as String?;
      final soldQuantity = saleDetails['quantity'] as int?;

      if (barcode == null || soldQuantity == null) {
        developer.log('Sale record is missing barcode or quantity.');
        await txn.delete(tableSales, where: 'id = ?', whereArgs: [saleId]);
        return;
      }

      final itemDetailsList = await txn.query(
        tableItems,
        columns: ['quantity'],
        where: 'barcode = ?',
        whereArgs: [barcode],
        limit: 1,
      );

      if (itemDetailsList.isNotEmpty) {
        final currentQuantity = itemDetailsList.first['quantity'] as int? ?? 0;
        final newQuantity = currentQuantity + soldQuantity;
        await txn.update(
          tableItems,
          {
            'quantity': newQuantity,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'barcode = ?',
          whereArgs: [barcode],
        );
      } else {
        developer.log(
          'Item with barcode $barcode not found to restore quantity.',
        );
      }

      await txn.delete(tableSales, where: 'id = ?', whereArgs: [saleId]);
    });

    notifyDataChanged();
  }

  // **FIXED:** This method is now designed to be part of a transaction
  Future<int> addDebt({
    required String customerName,
    String? customerPhone,
    required String customerAddress,
    required double totalAmount,
    double paidAmount = 0.0,
    required double debtAmount,
    required String saleDate,
    required String currency,
    required double exchangeRate,
    // New optional parameter for the transaction object
    Transaction? transaction,
  }) async {
    // Use the provided transaction object or get a new database instance
    final db = transaction ?? await database;
    final now = DateTime.now().toIso8601String();
    try {
      final id = await db.insert(tableDebts, {
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_address': customerAddress,
        'total_amount': totalAmount,
        'paid_amount': paidAmount,
        'debt_amount': debtAmount,
        'sale_date': saleDate,
        'currency': currency,
        'exchange_rate': exchangeRate,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.rollback);
      // Only notify if not part of a transaction, as the main transaction will handle it
      if (transaction == null) {
        notifyDataChanged();
      }
      return id;
    } catch (e) {
      developer.log('Error adding debt record', error: e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getDebt(int id) async {
    final db = await database;
    final maps = await db.query(tableDebts, where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? null : maps.first;
  }

  // NEW: Function to retrieve all debt records
  Future<List<Map<String, dynamic>>> getAllDebts() async {
    final db = await database;
    try {
      return await db.query(tableDebts, orderBy: 'created_at DESC');
    } catch (e) {
      developer.log('Error fetching all debts', error: e);
      throw Exception('Failed to fetch all debts: ${e.toString()}');
    }
  }

  Future<int> updateDebt(Map<String, dynamic> debt) async {
    final db = await database;
    if (debt['id'] == null) {
      throw ArgumentError('Debt must have an ID to be updated');
    }
    final newDebt = Map<String, dynamic>.from(debt);
    newDebt['updated_at'] = DateTime.now().toIso8601String();
    final result = await db.update(
      tableDebts,
      newDebt,
      where: 'id = ?',
      whereArgs: [debt['id']],
    );
    notifyDataChanged();
    return result;
  }

  Future<int> deleteDebt(int id) async {
    final db = await database;
    return await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }
}
