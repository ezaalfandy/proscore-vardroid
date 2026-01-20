import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/device.dart';
import '../models/session.dart';
import '../models/mark.dart';
import '../models/clip.dart';
import '../models/pairing_token.dart';

/// Service for managing SQLite database operations.
class DatabaseService {
  static const String _databaseName = 'proscore_var.db';
  static const int _databaseVersion = 1;

  Database? _database;

  /// Get the database instance, initializing if needed.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database.
  Future<Database> _initDatabase() async {
    // Initialize FFI for desktop platforms
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Get application data directory
    final appDataDir = Platform.environment['LOCALAPPDATA'] ?? '.';
    final dbDir = Directory(p.join(appDataDir, 'ProScoreVAR'));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    final dbPath = p.join(dbDir.path, _databaseName);
    print('Database path: $dbPath');

    return await openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE devices (
        id TEXT PRIMARY KEY,
        device_key TEXT NOT NULL UNIQUE,
        assigned_name TEXT NOT NULL,
        slot_name TEXT,
        device_name TEXT,
        platform TEXT,
        app_version TEXT,
        max_resolution TEXT,
        max_fps INTEGER,
        paired_at INTEGER NOT NULL,
        last_seen_at INTEGER,
        is_active INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        event_id TEXT,
        match_id TEXT,
        title TEXT,
        started_at INTEGER,
        stopped_at INTEGER,
        status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE marks (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        coordinator_ts INTEGER NOT NULL,
        label TEXT,
        note TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE mark_acks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mark_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        device_ts INTEGER NOT NULL,
        received_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE clips (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        mark_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        source_url TEXT,
        local_path TEXT,
        duration_ms INTEGER,
        size_bytes INTEGER,
        status TEXT DEFAULT 'pending',
        download_progress REAL DEFAULT 0,
        error_message TEXT,
        created_at INTEGER NOT NULL,
        downloaded_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE pairing_tokens (
        token TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        used INTEGER DEFAULT 0
      )
    ''');

    // Create indexes for common queries
    await db.execute('CREATE INDEX idx_marks_session ON marks(session_id)');
    await db.execute('CREATE INDEX idx_clips_session ON clips(session_id)');
    await db.execute('CREATE INDEX idx_clips_mark ON clips(mark_id)');
    await db.execute('CREATE INDEX idx_mark_acks_mark ON mark_acks(mark_id)');

    print('Database tables created successfully');
  }

  /// Handle database upgrades.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future migrations here
  }

  // ==================== Device Operations ====================

  Future<void> insertDevice(Device device) async {
    final db = await database;
    await db.insert('devices', device.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateDevice(Device device) async {
    final db = await database;
    await db.update(
      'devices',
      device.toMap(),
      where: 'id = ?',
      whereArgs: [device.id],
    );
  }

  Future<Device?> getDeviceById(String id) async {
    final db = await database;
    final maps = await db.query('devices', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Device.fromMap(maps.first);
  }

  Future<Device?> getDeviceByKey(String deviceKey) async {
    final db = await database;
    final maps = await db.query('devices',
        where: 'device_key = ?', whereArgs: [deviceKey]);
    if (maps.isEmpty) return null;
    return Device.fromMap(maps.first);
  }

  Future<List<Device>> getAllDevices() async {
    final db = await database;
    final maps = await db.query('devices', orderBy: 'paired_at DESC');
    return maps.map((map) => Device.fromMap(map)).toList();
  }

  Future<void> deleteDevice(String id) async {
    final db = await database;
    await db.delete('devices', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateDeviceLastSeen(String id) async {
    final db = await database;
    await db.update(
      'devices',
      {'last_seen_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Session Operations ====================

  Future<void> insertSession(Session session) async {
    final db = await database;
    await db.insert('sessions', session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSession(Session session) async {
    final db = await database;
    await db.update(
      'sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<Session?> getSessionById(String id) async {
    final db = await database;
    final maps = await db.query('sessions', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Session.fromMap(maps.first);
  }

  Future<List<Session>> getAllSessions() async {
    final db = await database;
    final maps = await db.query('sessions', orderBy: 'started_at DESC');
    return maps.map((map) => Session.fromMap(map)).toList();
  }

  Future<Session?> getActiveSession() async {
    final db = await database;
    final maps = await db.query('sessions',
        where: 'status = ?', whereArgs: ['recording'], limit: 1);
    if (maps.isEmpty) return null;
    return Session.fromMap(maps.first);
  }

  // ==================== Mark Operations ====================

  Future<void> insertMark(Mark mark) async {
    final db = await database;
    await db.insert('marks', mark.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateMark(Mark mark) async {
    final db = await database;
    await db.update(
      'marks',
      mark.toMap(),
      where: 'id = ?',
      whereArgs: [mark.id],
    );
  }

  Future<Mark?> getMarkById(String id) async {
    final db = await database;
    final maps = await db.query('marks', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Mark.fromMap(maps.first);
  }

  Future<List<Mark>> getMarksBySession(String sessionId) async {
    final db = await database;
    final maps = await db.query('marks',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'coordinator_ts ASC');
    return maps.map((map) => Mark.fromMap(map)).toList();
  }

  Future<void> deleteMark(String id) async {
    final db = await database;
    await db.delete('marks', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== Mark Ack Operations ====================

  Future<void> insertMarkAck(MarkAck ack) async {
    final db = await database;
    await db.insert('mark_acks', ack.toMap());
  }

  Future<List<MarkAck>> getAcksByMark(String markId) async {
    final db = await database;
    final maps = await db.query('mark_acks',
        where: 'mark_id = ?', whereArgs: [markId]);
    return maps.map((map) => MarkAck.fromMap(map)).toList();
  }

  // ==================== Clip Operations ====================

  Future<void> insertClip(Clip clip) async {
    final db = await database;
    await db.insert('clips', clip.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateClip(Clip clip) async {
    final db = await database;
    await db.update(
      'clips',
      clip.toMap(),
      where: 'id = ?',
      whereArgs: [clip.id],
    );
  }

  Future<Clip?> getClipById(String id) async {
    final db = await database;
    final maps = await db.query('clips', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Clip.fromMap(maps.first);
  }

  Future<List<Clip>> getClipsBySession(String sessionId) async {
    final db = await database;
    final maps = await db.query('clips',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'created_at DESC');
    return maps.map((map) => Clip.fromMap(map)).toList();
  }

  Future<List<Clip>> getClipsByMark(String markId) async {
    final db = await database;
    final maps = await db.query('clips',
        where: 'mark_id = ?', whereArgs: [markId], orderBy: 'created_at DESC');
    return maps.map((map) => Clip.fromMap(map)).toList();
  }

  Future<List<Clip>> getPendingClips() async {
    final db = await database;
    final maps = await db.query('clips',
        where: 'status IN (?, ?, ?)',
        whereArgs: ['pending', 'requested', 'generating']);
    return maps.map((map) => Clip.fromMap(map)).toList();
  }

  // ==================== Pairing Token Operations ====================

  Future<void> insertPairingToken(PairingToken token) async {
    final db = await database;
    await db.insert('pairing_tokens', token.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<PairingToken?> getPairingToken(String token) async {
    final db = await database;
    final maps = await db.query('pairing_tokens',
        where: 'token = ?', whereArgs: [token]);
    if (maps.isEmpty) return null;
    return PairingToken.fromMap(maps.first);
  }

  Future<void> markTokenUsed(String token) async {
    final db = await database;
    await db.update(
      'pairing_tokens',
      {'used': 1},
      where: 'token = ?',
      whereArgs: [token],
    );
  }

  Future<void> cleanupExpiredTokens() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.delete('pairing_tokens',
        where: 'expires_at < ? OR used = 1', whereArgs: [now]);
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
