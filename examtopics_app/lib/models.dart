import 'dart:convert';
import 'package:flutter/foundation.dart';

class Exam {
  final int? id;
  final String title;

  Exam({this.id, required this.title});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
    };
  }

  factory Exam.fromMap(Map<String, dynamic> map) {
    return Exam(
      id: map['id'],
      title: map['title'],
    );
  }
}

class Question {
  final int? id;
  final int examId;
  final String title;
  final String topic;
  final int? questionNumber;
  final String questionText;
  final String? correctAnswer;
  final List<Map<String, dynamic>>? voteDistribution;
  final List<Choice> choices;
  final List<DiscussionComment> discussion;
  final bool isMarkedForReview;

  Question({
    this.id,
    required this.examId,
    required this.title,
    required this.topic,
    this.questionNumber,
    required this.questionText,
    this.correctAnswer,
    this.voteDistribution,
    required this.choices,
    required this.discussion,
    this.isMarkedForReview = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'examId': examId,
      'title': title,
      'topic': topic,
      'questionNumber': questionNumber,
      'questionText': questionText,
      'correctAnswer': correctAnswer,
      'voteDistribution': jsonEncode(voteDistribution),
      'choices': jsonEncode(choices.map((choice) => choice.toMap()).toList()),
      'discussion': jsonEncode(discussion.map((comment) => comment.toMap()).toList()),
      'isMarkedForReview': isMarkedForReview ? 1 : 0,
    };
  }

  Question copyWith({
    int? id,
    int? examId,
    String? title,
    String? topic,
    int? questionNumber,
    String? questionText,
    String? correctAnswer,
    List<Map<String, dynamic>>? voteDistribution,
    List<Choice>? choices,
    List<DiscussionComment>? discussion,
    bool? isMarkedForReview,
  }) {
    return Question(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      title: title ?? this.title,
      topic: topic ?? this.topic,
      questionNumber: questionNumber ?? this.questionNumber,
      questionText: questionText ?? this.questionText,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      voteDistribution: voteDistribution ?? this.voteDistribution,
      choices: choices ?? this.choices,
      discussion: discussion ?? this.discussion,
      isMarkedForReview: isMarkedForReview ?? this.isMarkedForReview,
    );
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      examId: json['examId'] ?? 0, // Will be set when inserting into DB
      title: json['title'],
      topic: json['topic'],
      questionNumber: json['question_number'],
      questionText: json['question_text'],
      correctAnswer: json['correct_answer'],
      voteDistribution: json['vote_distribution'] != null
          ? (json['vote_distribution'] is String
              ? (jsonDecode(json['vote_distribution']) as List)
                  .map((item) => item as Map<String, dynamic>)
                  .toList()
              : (json['vote_distribution'] as List)
                  .map((item) => item as Map<String, dynamic>)
                  .toList())
          : null,
      choices: (json['choices'] as List)
          .map((choice) => Choice.fromJson(choice))
          .toList(),
      discussion: (json['discussion'] as List)
          .map((comment) => DiscussionComment.fromJson(comment))
          .toList(),
    );
  }
}

class Choice {
  final String letter;
  final String text;

  Choice({required this.letter, required this.text});

  Map<String, dynamic> toMap() {
    return {
      'letter': letter,
      'text': text,
    };
  }

  factory Choice.fromJson(Map<String, dynamic> json) {
    return Choice(
      letter: json['letter'],
      text: json['text'],
    );
  }
}

class DiscussionComment {
  final String author;
  final String date;
  final String comment;
  final String selectedAnswer;

  DiscussionComment({
    required this.author,
    required this.date,
    required this.comment,
    required this.selectedAnswer,
  });

  Map<String, dynamic> toMap() {
    return {
      'author': author,
      'date': date,
      'comment': comment,
      'selected_answer': selectedAnswer,
    };
  }

  factory DiscussionComment.fromJson(Map<String, dynamic> json) {
    return DiscussionComment(
      author: json['author'] ?? '',
      date: json['date'] ?? '',
      comment: json['comment'] ?? '',
      selectedAnswer: json['selected_answer'] ?? '',
    );
  }
}
