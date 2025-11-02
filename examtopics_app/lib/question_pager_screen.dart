import 'package:flutter/foundation.dart'; // Import for kIsWeb
import 'package:flutter/material.dart';
import 'package:examapp/models.dart';
import 'package:examapp/question_view.dart';

class QuestionPagerScreen extends StatefulWidget {
  final List<Question> questions;
  final int initialIndex;
  final Function(Question) onToggleReview;

  const QuestionPagerScreen({
    super.key,
    required this.questions,
    required this.initialIndex,
    required this.onToggleReview,
  });

  @override
  State<QuestionPagerScreen> createState() => _QuestionPagerScreenState();
}

class _QuestionPagerScreenState extends State<QuestionPagerScreen> {
  late final PageController _pageController;
  late List<Question> _questions;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _questions = List.from(widget.questions);
    _pageController.addListener(() {
      if (_pageController.page?.round() != _currentIndex) {
        setState(() {
          _currentIndex = _pageController.page!.round();
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleToggleReview(Question question) {
    widget.onToggleReview(question);
    setState(() {
      final index = _questions.indexWhere((q) => q.id == question.id);
      if (index != -1) {
        _questions[index] = question.copyWith(
          isMarkedForReview: !question.isMarkedForReview,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Questions')),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                return QuestionView(
                  question: _questions[index],
                  onToggleReview: _handleToggleReview,
                );
              },
            ),
          ),
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _currentIndex > 0
                        ? () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                    child: const Text('Previous'),
                  ),
                  ElevatedButton(
                    onPressed: _currentIndex < _questions.length - 1
                        ? () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
