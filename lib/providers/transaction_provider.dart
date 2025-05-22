import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/transaction.dart';

class TransactionProvider with ChangeNotifier {
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;
  double _totalFine = 0.0;
  final http.Client _client;

  TransactionProvider({http.Client? client}) : _client = client ?? http.Client();

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get totalFine => _totalFine;

  Future<void> fetchTransactions(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.get(
        Uri.parse('http://localhost:5000/api/transactions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      print('fetchTransactions response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _transactions = (data['transactions'] as List)
            .map((t) => Transaction.fromJson(t))
            .toList();
      } else if (response.statusCode == 401) {
        _errorMessage = 'Unauthorized. Please log in again.';
        throw Exception('Invalid token');
      } else {
        final errorData = jsonDecode(response.body);
        _errorMessage = errorData['message'] ?? 'Failed to fetch transactions: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Error fetching transactions: $e';
      print('fetchTransactions error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> fetchTransactionsByLibraryCard(String token, String libraryCardNo) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.get(
        Uri.parse('http://localhost:5000/api/admin/user-transactions?library_card_no=$libraryCardNo'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      print('fetchTransactionsByLibraryCard response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _transactions = (data['transactions'] as List)
            .map((t) => Transaction.fromJson(t))
            .toList();
        return {
          'user': data['user'],
          'total_fine': data['total_fine'] as double,
        };
      } else if (response.statusCode == 401) {
        _errorMessage = 'Unauthorized. Please log in again.';
        throw Exception('Invalid token');
      } else {
        final errorData = jsonDecode(response.body);
        _errorMessage = errorData['message'] ?? 'Failed to fetch transactions: ${response.statusCode}';
        return null;
      }
    } catch (e) {
      _errorMessage = 'Error fetching transactions by library card: $e';
      print('fetchTransactionsByLibraryCard error: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUserTransactions(String token) async {
    _isLoading = true;
    _errorMessage = null;
    _totalFine = 0.0;
    notifyListeners();

    try {
      final response = await _client.get(
        Uri.parse('http://localhost:5000/api/user/transactions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      print('fetchUserTransactions response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _transactions = (data['transactions'] as List)
            .map((t) => Transaction.fromJson(t))
            .toList();
        _totalFine = (data['total_fine'] as num?)?.toDouble() ?? 0.0;
      } else if (response.statusCode == 401) {
        _errorMessage = 'Unauthorized. Please log in again.';
        throw Exception('Invalid token');
      } else {
        final errorData = jsonDecode(response.body);
        _errorMessage = errorData['message'] ?? 'Failed to fetch user transactions: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Error fetching user transactions: $e';
      print('fetchUserTransactions error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> requestFinePayment(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.post(
        Uri.parse('http://localhost:5000/api/request-fine-payment'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      print('requestFinePayment response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        await fetchUserTransactions(token);
      } else if (response.statusCode == 401) {
        _errorMessage = 'Unauthorized. Please log in again.';
        throw Exception('Invalid token');
      } else {
        final errorData = jsonDecode(response.body);
        _errorMessage = errorData['message'] ?? 'Failed to request fine payment: ${response.statusCode}';
        throw Exception(_errorMessage);
      }
    } catch (e) {
      _errorMessage = 'Error requesting fine payment: $e';
      print('requestFinePayment error: $e');
      throw Exception('Error requesting fine payment: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> adminPayFine(String token, int userId, bool approve) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.post(
        Uri.parse('http://localhost:5000/api/admin/pay-fine'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'approve': approve,
        }),
      );
      print('adminPayFine response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        await fetchTransactions(token);
      } else if (response.statusCode == 401) {
        _errorMessage = 'Unauthorized. Please log in again.';
        throw Exception('Invalid token');
      } else {
        final errorData = jsonDecode(response.body);
        _errorMessage = errorData['message'] ?? 'Failed to process fine payment: ${response.statusCode}';
        throw Exception(_errorMessage);
      }
    } catch (e) {
      _errorMessage = 'Error processing fine payment: $e';
      print('adminPayFine error: $e');
      throw Exception('Error processing fine payment: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> confirmBorrow(String token, int userId, int bookId, String action) async {
    try {
      final response = await _client.post(
        Uri.parse('http://localhost:5000/api/borrow/confirm'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'book_id': bookId,
          'action': action,
        }),
      );
      print('confirmBorrow response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 401) {
        throw Exception('Invalid token');
      }
      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to confirm borrow: ${response.statusCode}');
      }
    } catch (e) {
      print('confirmBorrow error: $e');
      throw Exception('Error confirming borrow: $e');
    }
  }

  Future<void> confirmReturn(String token, int userId, int bookId, String action) async {
    try {
      final response = await _client.post(
        Uri.parse('http://localhost:5000/api/return/confirm'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'book_id': bookId,
          'action': action,
        }),
      );
      print('confirmReturn response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 401) {
        throw Exception('Invalid token');
      }
      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to confirm return: ${response.statusCode}');
      }
    } catch (e) {
      print('confirmReturn error: $e');
      throw Exception('Error confirming return: $e');
    }
  }
}