import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:examapp/models.dart';
import 'package:examapp/database_helper.dart';
import 'package:examapp/exam_home_screen.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const ExamTopicsApp());
}

class ExamTopicsApp extends StatelessWidget {
  const ExamTopicsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExamApp',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Exam> _exams = [];

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    final exams = await _databaseHelper.getExams();
    setState(() {
      _exams = exams;
    });
  }

  void _importExamPack() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        String jsonString;

        if (kIsWeb) {
          // On web, use bytes
          final bytes = file.bytes!;
          jsonString = utf8.decode(bytes);
        } else {
          // On mobile, use path
          String? filePath = file.path;
          if (filePath != null) {
            jsonString = await File(filePath).readAsString();
          } else {
            // Handle case where path is null on mobile
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to get file path.')),
            );
            return;
          }
        }

        List<dynamic> questionsJson = jsonDecode(jsonString);

        if (questionsJson.isNotEmpty) {
          String examTitle = questionsJson[0]['title'].split('topic')[0].trim();
          Exam newExam = Exam(title: examTitle);
          int examId = await _databaseHelper.insertExam(newExam);

          for (var qJson in questionsJson) {
            Question question = Question.fromJson(qJson);
            await _databaseHelper.insertQuestion(
              question.copyWith(examId: examId),
            );
          }
          _loadExams();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exam "$examTitle" imported successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected JSON file is empty.')),
          );
        }
      }
    } catch (e) {
      print('Error importing exam pack: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to import exam pack: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ExamApp')),
      body: _exams.isEmpty
          ? const Center(
              child: Text(
                'No exams imported yet. Tap the + button to import an exam pack.',
              ),
            )
          : ListView.builder(
              itemCount: _exams.length,
              itemBuilder: (context, index) {
                final exam = _exams[index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text(exam.title),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(exam),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExamHomeScreen(exam: exam),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _importExamPack,
        tooltip: 'Import Exam Pack',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(Exam exam) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Are you sure you want to delete the exam "${exam.title}"?',
                ),
                const Text('This action cannot be undone.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                await _databaseHelper.deleteExam(exam.id!);
                _loadExams();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Exam "${exam.title}" deleted.')),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
