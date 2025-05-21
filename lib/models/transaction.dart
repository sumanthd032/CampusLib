class Transaction {
  final int id;
  final int userId;
  final int bookId;
  final String borrowDate;
  final String? dueDate;
  final String? returnDate;
  final String status;
  final double fine;
  final bool finePaid;

  Transaction({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.borrowDate,
    this.dueDate,
    this.returnDate,
    required this.status,
    required this.fine,
    required this.finePaid,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as int? ?? (throw Exception('Transaction id cannot be null')),
      userId: json['user_id'] as int? ?? (throw Exception('Transaction user_id cannot be null')),
      bookId: json['book_id'] as int? ?? (throw Exception('Transaction book_id cannot be null')),
      borrowDate: json['borrow_date'] as String? ?? (throw Exception('Transaction borrow_date cannot be null')),
      dueDate: json['due_date'] as String?,
      returnDate: json['return_date'] as String?,
      status: json['status'] as String? ?? (throw Exception('Transaction status cannot be null')),
      fine: (json['fine'] as num?)?.toDouble() ?? 0.0,
      finePaid: json['fine_paid'] as bool? ?? false,  
    );
  }
}