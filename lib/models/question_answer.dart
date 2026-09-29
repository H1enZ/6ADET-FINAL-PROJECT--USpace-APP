/// One person's answer to a daily question. Mirrors `question_answers`.
class QuestionAnswer {
  const QuestionAnswer({
    required this.id,
    required this.userId,
    required this.questionDate,
    required this.question,
    required this.answer,
  });

  final String id;
  final String userId;
  final DateTime questionDate;
  final String question;
  final String answer;

  factory QuestionAnswer.fromMap(Map<String, dynamic> row) => QuestionAnswer(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        questionDate: DateTime.parse(row['question_date'] as String),
        question: row['question'] as String,
        answer: row['answer'] as String,
      );
}
