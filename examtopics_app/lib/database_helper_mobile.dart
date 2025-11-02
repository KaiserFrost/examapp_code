import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:examtopics_app/models.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'examtopics.db');
    return await openDatabase(
      path,
      version: 3, // Incremented version
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      'CREATE TABLE exams(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT)',
    );
    await db.execute(
      '''CREATE TABLE questions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        examId INTEGER,
        title TEXT,
        topic TEXT,
        questionNumber INTEGER,
        questionText TEXT,
        correctAnswer TEXT,
        voteDistribution TEXT, -- Stored as JSON string
        choices TEXT, -- Stored as JSON string
        discussion TEXT, -- Stored as JSON string
        isMarkedForReview INTEGER DEFAULT 0,
        FOREIGN KEY (examId) REFERENCES exams(id) ON DELETE CASCADE
      )''',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE questions ADD COLUMN isMarkedForReview INTEGER DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE questions ADD COLUMN voteDistribution TEXT');
    }
  }

  Future<int> insertExam(Exam exam) async {
    Database db = await database;
    return await db.insert('exams', exam.toMap());
  }

  Future<int> insertQuestion(Question question) async {
    Database db = await database;
    return await db.insert('questions', question.toMap());
  }

  Future<void> updateQuestionReviewStatus(int id, bool isMarkedForReview) async {
    Database db = await database;
    await db.update(
      'questions',
      {'isMarkedForReview': isMarkedForReview ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Exam>> getExams() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('exams');
    return List.generate(maps.length, (i) {
      return Exam.fromMap(maps[i]);
    });
  }

  Future<List<Question>> getQuestionsForExam(int examId) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'questions',
      where: 'examId = ?',
      whereArgs: [examId],
      orderBy: 'questionNumber ASC',
    );
    return List.generate(maps.length, (i) {
      return Question(
        id: maps[i]['id'],
        examId: maps[i]['examId'],
        title: maps[i]['title'],
        topic: maps[i]['topic'],
        questionNumber: maps[i]['questionNumber'],
        questionText: maps[i]['questionText'],
        correctAnswer: maps[i]['correctAnswer'],
        voteDistribution: maps[i]['voteDistribution'] != null
            ? (jsonDecode(maps[i]['voteDistribution']) as List)
                .map((e) => e as Map<String, dynamic>)
                .toList()
            : null,
        choices: (jsonDecode(maps[i]['choices']) as List)
            .map((e) => Choice.fromJson(e as Map<String, dynamic>))
            .toList(),
        discussion: (jsonDecode(maps[i]['discussion']) as List)
            .map((e) => DiscussionComment.fromJson(e as Map<String, dynamic>))
            .toList(),
        isMarkedForReview: maps[i]['isMarkedForReview'] == 1,
      );
    });
  }

  Future<void> deleteExam(int examId) async {
    Database db = await database;
    await db.delete(
      'exams',
      where: 'id = ?',
      whereArgs: [examId],
    );
    // Questions will be deleted automatically due to ON DELETE CASCADE
  }
}
