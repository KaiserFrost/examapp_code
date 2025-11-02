import 'package:flutter/material.dart';
import 'package:examtopics_app/models.dart';
import 'package:examtopics_app/database_helper.dart';
import 'package:examtopics_app/question_pager_screen.dart';

class ExamHomeScreen extends StatefulWidget {
  final Exam exam;

  const ExamHomeScreen({super.key, required this.exam});

  @override
  State<ExamHomeScreen> createState() => _ExamHomeScreenState();
}

class _ExamHomeScreenState extends State<ExamHomeScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  late TabController _tabController;
  List<Question> _questions = [];
  List<Question> _questionsForReview = [];
  List<Question> _allExamQuestions = []; // New: Unfiltered list of all questions
  List<Question> _allReviewQuestions = []; // New: Unfiltered list of all reviewed questions
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false; // New state variable

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // initialIndex 0 is now All Questions
    _searchController.addListener(_onSearchChanged);
    _loadQuestions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
    _loadQuestions(); // Reload questions with new search query
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        // _onSearchChanged will be called by listener, triggering _loadQuestions
      }
    });
  }

  Future<void> _loadQuestions() async {
    // Load all questions once and store in _allExamQuestions
    List<Question> fetchedQuestions = await _databaseHelper.getQuestionsForExam(widget.exam.id!); // Get all questions from DB

    setState(() {
      _allExamQuestions = fetchedQuestions; // Store the full list
      _allReviewQuestions = _allExamQuestions.where((q) => q.isMarkedForReview).toList(); // Populate full list of reviewed questions

      List<Question> currentDisplayedQuestions = _allExamQuestions; // Start with full list for search filtering

      if (_searchQuery.isNotEmpty) {
        currentDisplayedQuestions = _allExamQuestions.where((question) {
          final query = _searchQuery.toLowerCase();
          return question.questionText.toLowerCase().contains(query) ||
                 (question.questionNumber?.toString().contains(query) ?? false);
        }).toList();
      }

      _questions = currentDisplayedQuestions; // This is the list for "All Questions" tab, filtered by search
      _questionsForReview = _questions.where((q) => q.isMarkedForReview).toList(); // This is the list for "To Review" tab, filtered by search AND review status
    });
  }

  Future<void> _toggleReviewStatus(Question question) async {
    await _databaseHelper.updateQuestionReviewStatus(question.id!, !question.isMarkedForReview);
    _loadQuestions(); // Reload to reflect the change
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search questions...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)),
                ),
                style: const TextStyle(color: Colors.black, fontSize: 18.0),
              )
            : Text(widget.exam.title),
        actions: [
          IconButton(
            icon: _isSearching ? const Icon(Icons.close) : const Icon(Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Questions'),
            Tab(text: 'To Review'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          QuestionListView(key: const ValueKey('all_questions_list'), questions: _questions, onToggleReview: _toggleReviewStatus, allQuestions: _allExamQuestions, questionsToPage: _allExamQuestions),
          QuestionListView(key: const ValueKey('to_review_list'), questions: _questionsForReview, onToggleReview: _toggleReviewStatus, allQuestions: _allExamQuestions, questionsToPage: _allReviewQuestions),
        ],
      ),
    );
  }
}

class QuestionListView extends StatefulWidget {
  final List<Question> questions;
  final List<Question> allQuestions;
  final Function(Question) onToggleReview;
  final List<Question> questionsToPage; // Reintroduce this

  const QuestionListView({
    super.key,
    required this.questions,
    required this.onToggleReview,
    required this.allQuestions,
    required this.questionsToPage, // Reintroduce this
  });

  @override
  State<QuestionListView> createState() => _QuestionListViewState();
}

class _QuestionListViewState extends State<QuestionListView> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant QuestionListView oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.questions.length,
      itemBuilder: (context, index) {
        final question = widget.questions[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: ListTile(
            title: Text('Question ${question.questionNumber}'),
            trailing: IconButton(
              icon: Icon(
                question.isMarkedForReview ? Icons.star : Icons.star_border,
                color: question.isMarkedForReview ? Colors.amber : Colors.grey,
              ),
              onPressed: () => widget.onToggleReview(question),
            ),
            onTap: () {
              final originalIndex = widget.questionsToPage.indexOf(question);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuestionPagerScreen(
                    questions: widget.questionsToPage,
                    initialIndex: originalIndex,
                    onToggleReview: widget.onToggleReview,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}