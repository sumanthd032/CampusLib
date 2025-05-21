class Transaction {
  final int id;
  final int userId;
  final int bookId;
  final String borrowDate;
  final String? dueDate;
  final String? returnDate;
  final String status;
  final double fine;

  Transaction({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.borrowDate,
    this.dueDate,
    this.returnDate,
    required this.status,
    required this.fine,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      userId: json['user_id'],
      bookId: json['book_id'],
      borrowDate: json['borrow_date'],
      dueDate: json['due_date'],
      returnDate: json['return_date'],
      status: json['status'],
      fine: (json['fine'] as num?)?.toDouble() ?? 0.0,
    );
  }
}