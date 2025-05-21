import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/book_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/book.dart';

class ReaderDashboard extends StatefulWidget {
  @override
  _ReaderDashboardState createState() => _ReaderDashboardState();
}

class _ReaderDashboardState extends State<ReaderDashboard> {
  final _searchController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) {
      print('No token, redirecting to login');
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
      await Future.wait([
        bookProvider.fetchBooks(authProvider.token!),
        bookProvider.fetchCategories(authProvider.token!),
        transactionProvider.fetchUserTransactions(authProvider.token!),
      ]);
    } catch (e) {
      print('Initialize data error: $e');
      if (e.toString().contains('Invalid token')) {
        await authProvider.logout();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing data: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showQrCodeDialog(Map<String, dynamic> qrData) {
    final qrJson = jsonEncode({
      'user_id': int.parse(qrData['user_id'].toString()),
      'book_id': qrData['book_id'],
      'action': qrData['action'],
    });
    print('QR Code Data: $qrJson');
    showDialog(
      context: context,
      builder: (context) => FadeIn(
        duration: Duration(milliseconds: 300),
        child: AlertDialog(
          title: Text(
            qrData['action'] == 'borrow' ? 'Borrow QR Code' : 'Return QR Code',
            style: GoogleFonts.poppins(color: AppColors.primary),
          ),
          content: Container(
            width: 300.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 200.0,
                  height: 200.0,
                  child: QrImageView(
                    data: qrJson,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.all(10),
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  qrData['action'] == 'borrow'
                      ? 'Show this QR code to the librarian to borrow the book.'
                      : 'Show this QR code to the librarian to return the book.',
                  style: GoogleFonts.poppins(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: GoogleFonts.poppins(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = Provider.of<BookProvider>(context);
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('CampusLib Reader Dashboard', style: GoogleFonts.poppins()),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await authProvider.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: FadeIn(
          duration: Duration(milliseconds: 500),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fine Notification Banner
                if (transactionProvider.totalFine > 0)
                  Container(
                    padding: EdgeInsets.all(10),
                    margin: EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      border: Border.all(color: AppColors.error),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: AppColors.error),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You have an overdue fine of \$${transactionProvider.totalFine.toStringAsFixed(2)}. Please return your books to avoid additional charges.',
                            style: GoogleFonts.poppins(color: AppColors.error, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  'Browse Books',
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search by Title or Author',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search, color: AppColors.accent),
                        ),
                        onChanged: (value) async {
                          try {
                            await bookProvider.fetchBooks(authProvider.token!, query: value, category: _selectedCategory ?? '');
                          } catch (e) {
                            if (e.toString().contains('Invalid token')) {
                              await authProvider.logout();
                              Navigator.pushReplacementNamed(context, '/login');
                            }
                          }
                        },
                      ),
                    ),
                    SizedBox(width: 10),
                    DropdownButton<String>(
                      hint: Text('Filter by Category', style: GoogleFonts.poppins()),
                      value: _selectedCategory,
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text('All Categories', style: GoogleFonts.poppins()),
                        ),
                        ...bookProvider.categories.map((category) => DropdownMenuItem(
                              value: category,
                              child: Text(category, style: GoogleFonts.poppins()),
                            )),
                      ],
                      onChanged: (value) async {
                        setState(() {
                          _selectedCategory = value;
                        });
                        try {
                          await bookProvider.fetchBooks(authProvider.token!, query: _searchController.text, category: value ?? '');
                        } catch (e) {
                          if (e.toString().contains('Invalid token')) {
                            await authProvider.logout();
                            Navigator.pushReplacementNamed(context, '/login');
                          }
                        }
                      },
                    ),
                  ],
                ),
                SizedBox(height: 20),
                SizedBox(
                  height: 300,
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : bookProvider.errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Error: ${bookProvider.errorMessage}',
                                    style: GoogleFonts.poppins(color: AppColors.error),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 10),
                                  ElevatedButton(
                                    onPressed: _initializeData,
                                    child: Text('Retry', style: GoogleFonts.poppins()),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                                  ),
                                ],
                              ),
                            )
                          : bookProvider.books.isEmpty
                              ? Center(child: Text('No books found', style: GoogleFonts.poppins()))
                              : ListView.builder(
                                  itemCount: bookProvider.books.length,
                                  itemBuilder: (context, index) {
                                    final book = bookProvider.books[index];
                                    return Card(
                                      elevation: 5,
                                      margin: EdgeInsets.symmetric(vertical: 10),
                                      child: ListTile(
                                        title: Text(book.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                        subtitle: Text(
                                          'Author: ${book.author} | Category: ${book.category} | Available: ${book.availableCopies}/${book.totalCopies}',
                                          style: GoogleFonts.poppins(),
                                        ),
                                        trailing: book.availableCopies > 0
                                            ? ElevatedButton(
                                                onPressed: () async {
                                                  setState(() {
                                                    _isLoading = true;
                                                  });
                                                  try {
                                                    final qrData = await bookProvider.requestBorrow(
                                                      book.bookId,
                                                      authProvider.token!,
                                                    );
                                                    _showQrCodeDialog(qrData);
                                                  } catch (e) {
                                                    if (e.toString().contains('Invalid token')) {
                                                      await authProvider.logout();
                                                      Navigator.pushReplacementNamed(context, '/login');
                                                    } else {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text('Error: $e'),
                                                          backgroundColor: AppColors.error,
                                                        ),
                                                      );
                                                    }
                                                  } finally {
                                                    setState(() {
                                                      _isLoading = false;
                                                    });
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.accent,
                                                ),
                                                child: Text('Borrow', style: GoogleFonts.poppins()),
                                              )
                                            : Text('Not Available', style: GoogleFonts.poppins(color: AppColors.error)),
                                      ),
                                    );
                                  },
                                ),
                ),
                SizedBox(height: 20),
                Text(
                  'My Borrowed Books',
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                SizedBox(height: 20),
                SizedBox(
                  height: 300,
                  child: transactionProvider.isLoading
                      ? Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : transactionProvider.errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Error: ${transactionProvider.errorMessage}',
                                    style: GoogleFonts.poppins(color: AppColors.error),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 10),
                                  ElevatedButton(
                                    onPressed: _initializeData,
                                    child: Text('Retry', style: GoogleFonts.poppins()),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                                  ),
                                ],
                              ),
                            )
                          : transactionProvider.transactions.where((t) => t.status == 'borrowed').isEmpty
                              ? Center(child: Text('No borrowed books', style: GoogleFonts.poppins()))
                              : ListView.builder(
                                  itemCount: transactionProvider.transactions.where((t) => t.status == 'borrowed').length,
                                  itemBuilder: (context, index) {
                                    final transaction = transactionProvider.transactions
                                        .where((t) => t.status == 'borrowed')
                                        .elementAt(index);
                                    final book = bookProvider.books.firstWhere(
                                      (b) => b.bookId == transaction.bookId,
                                      orElse: () => Book(
                                        bookId: 0,
                                        title: 'Unknown',
                                        author: 'Unknown',
                                        isbn: '',
                                        category: '',
                                        totalCopies: 0,
                                        availableCopies: 0,
                                      ),
                                    );
                                    return Card(
                                      elevation: 5,
                                      margin: EdgeInsets.symmetric(vertical: 10),
                                      child: ListTile(
                                        title: Text(book.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                        subtitle: Text(
                                          'Author: ${book.author} | Borrowed on: ${transaction.borrowDate} | Due: ${transaction.dueDate ?? 'N/A'} | Fine: \$${transaction.fine.toStringAsFixed(2)}',
                                          style: GoogleFonts.poppins(),
                                        ),
                                        trailing: ElevatedButton(
                                          onPressed: () {
                                            final qrData = {
                                              'user_id': transaction.userId,
                                              'book_id': transaction.bookId,
                                              'action': 'return',
                                            };
                                            _showQrCodeDialog(qrData);
                                          },
                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                                          child: Text('Return', style: GoogleFonts.poppins()),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}