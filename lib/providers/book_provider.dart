import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/book.dart';
import '../constants/app_colors.dart';
import 'auth_provider.dart';

class BookProvider with ChangeNotifier {
  List<Book> _books = [];
  List<String> _categories = [];
  String? _errorMessage;

  List<Book> get books => _books;
  List<String> get categories => _categories;
  String? get errorMessage => _errorMessage;

  Future<void> fetchBooks(String token, {String query = '', String category = ''}) async {
    try {
      _errorMessage = null;
      final uri = Uri.parse('http://localhost:5000/api/books').replace(queryParameters: {
        if (query.isNotEmpty) 'query': query,
        if (category.isNotEmpty) 'category': category,
      });
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      print('fetchBooks response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _books = (data['books'] as List).map((item) => Book.fromJson(item)).toList();
      } else if (response.statusCode == 422) {
        _errorMessage = 'Session expired. Please log in again.';
        throw Exception('Invalid token');
      } else {
        final errorData = jsonDecode(response.body);
        _errorMessage = errorData['message'] ?? 'Failed to load books: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Error fetching books: $e';
      print('fetchBooks error: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> fetchCategories(String token) async {
    try {
      _errorMessage = null;
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/categories'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      print('fetchCategories response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _categories = List<String>.from(data['categories']);
      } else if (response.statusCode == 422) {
        _errorMessage = 'Session expired. Please log in again.';
        throw Exception('Invalid token');
      } else {
        final errorData = jsonDecode(response.body);
        _errorMessage = errorData['message'] ?? 'Failed to load categories: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Error fetching categories: $e';
      print('fetchCategories error: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> requestBorrow(int bookId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/borrow/request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'book_id': bookId}),
      );
      print('requestBorrow response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['qr_data'];
      } else if (response.statusCode == 422) {
        throw Exception('Invalid token');
      } else {
        throw Exception('Failed to request borrow: ${response.statusCode}');
      }
    } catch (e) {
      print('requestBorrow error: $e');
      throw Exception('Error requesting borrow: $e');
    }
  }

  Future<void> addBook(Book book, String token) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/books'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(book.toJson()),
      );
      print('addBook response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 201) {
        await fetchBooks(token);
      } else if (response.statusCode == 422) {
        throw Exception('Invalid token');
      } else {
        throw Exception('Failed to add book: ${response.statusCode}');
      }
    } catch (e) {
      print('addBook error: $e');
      throw Exception('Error adding book: $e');
    }
  }

  Future<void> updateBook(int bookId, Book book, String token) async {
    try {
      final response = await http.put(
        Uri.parse('http://localhost:5000/api/books/$bookId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(book.toJson()),
      );
      print('updateBook response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        await fetchBooks(token);
      } else if (response.statusCode == 422) {
        throw Exception('Invalid token');
      } else {
        throw Exception('Failed to update book: ${response.statusCode}');
      }
    } catch (e) {
      print('updateBook error: $e');
      throw Exception('Error updating book: $e');
    }
  }

  Future<void> deleteBook(int bookId, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('http://localhost:5000/api/books/$bookId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      print('deleteBook response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        await fetchBooks(token);
      } else if (response.statusCode == 422) {
        throw Exception('Invalid token');
      } else {
        throw Exception('Failed to delete book: ${response.statusCode}');
      }
    } catch (e) {
      print('deleteBook error: $e');
      throw Exception('Error deleting book: $e');
    }
  }
}