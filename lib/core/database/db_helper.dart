// ALTERA SQLite veritabanı yöneticisi - tüm kalıcı veri burada
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';

import '../constants/app_constants.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/agent_log_entry.dart';

/// ALTERA SQLite veritabanı yöneticisi.
/// Singleton pattern kullanır - uygulama boyunca tek instance.
/// Tablolar: transactions, budgets, agent_logs, investment_records
///
/// Kullanım:
/// ```dart
/// final db = DbHelper();
/// await db.insertTransaction(tx);
/// final list = await db.getTransactions();
/// ```
class DbHelper {
  DbHelper._internal();
  static final DbHelper _instance = DbHelper._internal();

  /// Uygulama genelinde erişim için factory constructor
  factory DbHelper() => _instance;

  Database? _database;

  /// Veritabanını başlatır veya mevcut bağlantıyı döndürür
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.kDatabaseName);

    return openDatabase(
      path,
      version: AppConstants.kDatabaseVersion,
      onCreate: _onCreate,
    );
  }

  /// Veritabanı ilk kez oluşturulduğunda çağrılır
  Future<void> _onCreate(Database db, int version) async {
    // İşlemler tablosu - banka ve fatura verileri
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        type TEXT NOT NULL,
        ai_reason TEXT,
        is_analyzed INTEGER NOT NULL DEFAULT 0,
        source TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Bütçe tablosu - kategori bazlı aylık limitler
    // UNIQUE(category, month): aynı ay-kategori çifti tekrar edemez
    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        limit_amount REAL NOT NULL,
        month TEXT NOT NULL,
        UNIQUE(category, month)
      )
    ''');

    // Ajan log tablosu - her ajan kararı buraya yazılır
    await db.execute('''
      CREATE TABLE agent_logs (
        id TEXT PRIMARY KEY,
        agent TEXT NOT NULL,
        message TEXT NOT NULL,
        detail TEXT,
        timestamp TEXT NOT NULL,
        level TEXT NOT NULL,
        duration_ms INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Yatırım kayıtları - simüle transferler
    await db.execute('''
      CREATE TABLE investment_records (
        id TEXT PRIMARY KEY,
        fund_id TEXT NOT NULL,
        fund_name TEXT NOT NULL,
        amount REAL NOT NULL,
        action TEXT NOT NULL,
        date TEXT NOT NULL,
        ai_reason TEXT
      )
    ''');

    // İşlem tarihi için index - filtrelemede performans
    await db.execute('CREATE INDEX idx_tx_date ON transactions(date)');

    // Ajan log timestamp index - son kayıtlara hızlı erişim
    await db.execute('CREATE INDEX idx_log_ts ON agent_logs(timestamp)');
  }

  // ─────────────────────────────────────────────────────────────
  // TRANSACTION CRUD
  // ─────────────────────────────────────────────────────────────

  /// Yeni işlem ekler - duplicate durumunda sessizce atlar
  Future<void> insertTransaction(Transaction tx) async {
    final db = await database;
    await db.insert(
      'transactions',
      {
        'id': tx.id,
        'description': tx.description,
        'amount': tx.amount,
        'date': tx.date.toIso8601String(),
        'category': tx.category.name,
        'type': tx.type.name,
        'ai_reason': tx.aiReason,
        'is_analyzed': tx.isAnalyzed ? 1 : 0,
        'source': tx.source,
        'created_at': tx.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// İşlemleri listeler - opsiyonel tarih ve kategori filtresi
  Future<List<Transaction>> getTransactions({
    DateTime? fromDate,
    TransactionCategory? category,
    int? limit,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (fromDate != null) {
      conditions.add('date >= ?');
      args.add(fromDate.toIso8601String());
    }
    if (category != null) {
      conditions.add('category = ?');
      args.add(category.name);
    }

    final where = conditions.isNotEmpty ? conditions.join(' AND ') : null;
    final maps = await db.query(
      'transactions',
      where: where,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'date DESC',
      limit: limit,
    );

    return maps.map(_txFromMap).toList();
  }

  /// Henüz Gemini tarafından analiz edilmemiş işlemleri döndürür
  Future<List<Transaction>> getUnanalyzedTransactions({int limit = 20}) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'is_analyzed = 0',
      orderBy: 'date ASC',
      limit: limit,
    );
    return maps.map(_txFromMap).toList();
  }

  /// Gemini analiz sonucunu kaydeder
  Future<void> updateTransactionAnalysis(
    String id,
    TransactionCategory category,
    TransactionType type,
    String reason,
  ) async {
    final db = await database;
    await db.update(
      'transactions',
      {
        'category': category.name,
        'type': type.name,
        'ai_reason': reason,
        'is_analyzed': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Belirli bir ID'nin DB'de var olup olmadığını kontrol eder
  Future<bool> transactionExists(String id) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Transaction _txFromMap(Map<String, dynamic> map) => Transaction(
        id: map['id'] as String,
        description: map['description'] as String,
        amount: map['amount'] as double,
        date: DateTime.parse(map['date'] as String),
        category: TransactionCategory.values.byName(map['category'] as String),
        type: TransactionType.values.byName(map['type'] as String),
        aiReason: map['ai_reason'] as String?,
        isAnalyzed: (map['is_analyzed'] as int) == 1,
        source: map['source'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  // ─────────────────────────────────────────────────────────────
  // BUDGET CRUD
  // ─────────────────────────────────────────────────────────────

  /// Bütçe limiti ekler veya günceller (INSERT OR REPLACE)
  Future<void> upsertBudget(Budget budget) async {
    final db = await database;
    final monthStr =
        '${budget.month.year}-${budget.month.month.toString().padLeft(2, '0')}';
    await db.insert(
      'budgets',
      {
        'id': budget.id,
        'category': budget.category.name,
        'limit_amount': budget.limitAmount,
        'month': monthStr,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Belirtilen ay için bütçeleri döndürür (harcama miktarı hesaplanır)
  Future<List<Budget>> getBudgetsForMonth(DateTime month) async {
    final db = await database;
    final monthStr =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';

    final budgetMaps = await db.query(
      'budgets',
      where: 'month = ?',
      whereArgs: [monthStr],
    );

    // Her bütçe için o aydaki harcamayı hesapla
    final budgets = <Budget>[];
    for (final map in budgetMaps) {
      final category = TransactionCategory.values.byName(map['category'] as String);
      final spent = await _getMonthlySpent(category, month);

      budgets.add(Budget(
        id: map['id'] as String,
        category: category,
        limitAmount: map['limit_amount'] as double,
        spentAmount: spent,
        month: month,
      ));
    }

    return budgets;
  }

  /// Bütçeyi siler
  Future<void> deleteBudget(String id) async {
    final db = await database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────────────────────────
  // AGENT LOG
  // ─────────────────────────────────────────────────────────────

  /// Yeni ajan log kaydı ekler
  Future<void> insertLog(AgentLogEntry entry) async {
    final db = await database;
    await db.insert('agent_logs', {
      'id': entry.id,
      'agent': entry.agent.shortName,
      'message': entry.message,
      'detail': entry.detail,
      'timestamp': entry.timestamp.toIso8601String(),
      'level': entry.level.name,
      'duration_ms': entry.durationMs,
    });

    // Maksimum kayıt sayısını aştıysa eski kayıtları temizle
    await deleteOldLogs(AppConstants.kMaxAgentLogEntries);
  }

  /// Son logları döndürür - en yenisi başta
  Future<List<AgentLogEntry>> getRecentLogs({
    int limit = 100,
    AgentType? agent,
  }) async {
    final db = await database;
    final maps = await db.query(
      'agent_logs',
      where: agent != null ? 'agent = ?' : null,
      whereArgs: agent != null ? [agent.shortName] : null,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map(_logFromMap).toList();
  }

  /// Eski log kayıtlarını siler, son [keepCount] kaydı tutar
  Future<void> deleteOldLogs(int keepCount) async {
    final db = await database;
    await db.execute('''
      DELETE FROM agent_logs
      WHERE id NOT IN (
        SELECT id FROM agent_logs ORDER BY timestamp DESC LIMIT $keepCount
      )
    ''');
  }

  /// Tüm log kayıtlarını siler
  Future<void> clearAllLogs() async {
    final db = await database;
    await db.delete('agent_logs');
  }

  AgentLogEntry _logFromMap(Map<String, dynamic> map) {
    final agentStr = map['agent'] as String;
    final agentType = AgentType.values.firstWhere(
      (a) => a.shortName == agentStr,
      orElse: () => AgentType.orchestrator,
    );

    return AgentLogEntry(
      id: map['id'] as String,
      agent: agentType,
      message: map['message'] as String,
      detail: map['detail'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      level: LogLevel.values.byName(map['level'] as String),
      durationMs: map['duration_ms'] as int? ?? 0,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // YATIRIM KAYITLARI
  // ─────────────────────────────────────────────────────────────

  /// Simüle yatırım transferini kaydeder
  Future<void> insertInvestmentRecord({
    required String id,
    required String fundId,
    required String fundName,
    required double amount,
    required String action,
    String? aiReason,
  }) async {
    final db = await database;
    await db.insert('investment_records', {
      'id': id,
      'fund_id': fundId,
      'fund_name': fundName,
      'amount': amount,
      'action': action,
      'date': DateTime.now().toIso8601String(),
      'ai_reason': aiReason,
    });
  }

  /// Yatırım geçmişini döndürür
  Future<List<Map<String, dynamic>>> getInvestmentHistory({int limit = 20}) async {
    final db = await database;
    return db.query('investment_records', orderBy: 'date DESC', limit: limit);
  }

  // ─────────────────────────────────────────────────────────────
  // İSTATİSTİK SORGULARI
  // ─────────────────────────────────────────────────────────────

  /// Belirli ay için kategori bazlı gider toplamları
  Future<Map<TransactionCategory, double>> getMonthlySpendingByCategory(
      DateTime month) async {
    final db = await database;
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final maps = await db.rawQuery('''
      SELECT category, SUM(ABS(amount)) as total
      FROM transactions
      WHERE date >= ? AND date < ? AND amount < 0
      GROUP BY category
    ''', [start.toIso8601String(), end.toIso8601String()]);

    final result = <TransactionCategory, double>{};
    for (final map in maps) {
      try {
        final category = TransactionCategory.values.byName(map['category'] as String);
        result[category] = (map['total'] as num).toDouble();
      } catch (_) {
        // Geçersiz kategori adı - atla
      }
    }
    return result;
  }

  /// Belirli ay ve kategori için toplam gider
  Future<double> _getMonthlySpent(
      TransactionCategory category, DateTime month) async {
    final db = await database;
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final result = await db.rawQuery('''
      SELECT SUM(ABS(amount)) as total
      FROM transactions
      WHERE category = ? AND date >= ? AND date < ? AND amount < 0
    ''', [category.name, start.toIso8601String(), end.toIso8601String()]);

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Bu ay toplam gelir
  Future<double> getMonthlyIncome(DateTime month) async {
    final db = await database;
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final result = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM transactions
      WHERE date >= ? AND date < ? AND amount > 0
    ''', [start.toIso8601String(), end.toIso8601String()]);

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Bu ay toplam gider (mutlak değer)
  Future<double> getMonthlyExpense(DateTime month) async {
    final db = await database;
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final result = await db.rawQuery('''
      SELECT SUM(ABS(amount)) as total
      FROM transactions
      WHERE date >= ? AND date < ? AND amount < 0
    ''', [start.toIso8601String(), end.toIso8601String()]);

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Bu haftaki ve geçen haftaki gider toplamını karşılaştırır
  Future<({double thisWeek, double lastWeek})> getWeeklySpendingComparison() async {
    final db = await database;
    final now = DateTime.now();
    final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    Future<double> weeklySpend(DateTime from, DateTime to) async {
      final result = await db.rawQuery('''
        SELECT SUM(ABS(amount)) as total
        FROM transactions
        WHERE date >= ? AND date < ? AND amount < 0
      ''', [from.toIso8601String(), to.toIso8601String()]);
      return (result.first['total'] as num?)?.toDouble() ?? 0.0;
    }

    return (
      thisWeek: await weeklySpend(thisWeekStart, now),
      lastWeek: await weeklySpend(lastWeekStart, thisWeekStart),
    );
  }

  /// Tüm veritabanını sıfırlar (settings ekranında kullanılır)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('budgets');
    await db.delete('agent_logs');
    await db.delete('investment_records');
  }
}
