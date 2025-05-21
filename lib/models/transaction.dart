class Transaction {
  final int id;
  final int userId;
  final int bookId;
  final String borrowDate;
  final String? returnDate;
  final String status;

  Transaction({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.borrowDate,
    this.returnDate,
    required this.status,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      userId: json['user_id'],
      bookId: json['book_id'],
      borrowDate: json['borrow_date'],
      returnDate: json['return_date'],
      status: json['status'],
    );
  }
}