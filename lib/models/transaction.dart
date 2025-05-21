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
  final String? paymentStatus; // Added paymentStatus field

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
    this.paymentStatus,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      bookId: json['book_id'] as int,
      borrowDate: json['borrow_date'] as String,
      dueDate: json['due_date'] as String?,
      returnDate: json['return_date'] as String?,
      status: json['status'] as String,
      fine: (json['fine'] as num).toDouble(),
      finePaid: json['fine_paid'] as bool,
      paymentStatus: json['payment_status'] as String?,
    );
  }
}