class Book {
  final int bookId;
  final String title;
  final String author;
  final String isbn;
  final String category;
  final int totalCopies;
  final int availableCopies;

  Book({
    required this.bookId,
    required this.title,
    required this.author,
    required this.isbn,
    required this.category,
    required this.totalCopies,
    required this.availableCopies,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      bookId: json['book_id'],
      title: json['title'],
      author: json['author'],
      isbn: json['isbn'],
      category: json['category'],
      totalCopies: json['total_copies'],
      availableCopies: json['available_copies'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'author': author,
      'isbn': isbn,
      'category': category,
      'total_copies': totalCopies,
    };
  }
}