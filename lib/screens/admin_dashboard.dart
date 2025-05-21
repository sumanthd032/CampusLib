import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/book_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/book.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _isbnController = TextEditingController();
  final _categoryController = TextEditingController();
  final _copiesController = TextEditingController();
  final _qrDataController = TextEditingController();
  bool _isLoading = false;
  QRViewController? _qrController;
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');

  @override
  void initState() {
    super.initState();
    _initializeData();
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
        transactionProvider.fetchTransactions(authProvider.token!),
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

  void _onQRViewCreated(QRViewController controller) {
    _qrController = controller;
    Permission.camera.request().then((status) async {
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera permission denied. Please enable in settings.'),
            backgroundColor: AppColors.error,
          ),
        );
        Navigator.pop(context);
        return;
      }
      controller.scannedDataStream.listen((scanData) async {
        if (scanData.code != null) {
          controller.pauseCamera();
          await _processQRData(scanData.code!);
          controller.resumeCamera();
        }
      });
    });
  }

  Future<void> _processQRData(String qrCode) async {
    try {
      final qrData = jsonDecode(qrCode);
      final action = qrData['action'];
      if (!['borrow', 'return'].contains(action)) {
        throw Exception('Invalid QR code action: $action');
      }
      final userId = int.tryParse(qrData['user_id'].toString());
      if (userId == null) {
        throw Exception('Invalid user_id format: ${qrData['user_id']}');
      }
      final bookId = qrData['book_id'];
      if (bookId is! int) {
        throw Exception('Invalid book_id format: $bookId');
      }
      final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (action == 'borrow') {
        await transactionProvider.confirmBorrow(
          authProvider.token!,
          userId,
          bookId,
          action,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Borrow request confirmed!'),
            backgroundColor: AppColors.accent,
          ),
        );
      } else if (action == 'return') {
        await transactionProvider.confirmReturn(
          authProvider.token!,
          userId,
          bookId,
          action,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Return request confirmed!'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
      await transactionProvider.fetchTransactions(authProvider.token!);
    } catch (e) {
      print('QR process error: $e');
      if (e.toString().contains('Invalid token')) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.logout();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing QR code: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _qrController?.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    _categoryController.dispose();
    _copiesController.dispose();
    _qrDataController.dispose();
    super.dispose();
  }

  void _showAddBookDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Book', style: GoogleFonts.poppins(color: AppColors.primary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _authorController,
                decoration: InputDecoration(
                  labelText: 'Author',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _isbnController,
                decoration: InputDecoration(
                  labelText: 'ISBN',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _copiesController,
                decoration: InputDecoration(
                  labelText: 'Total Copies',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.error)),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });
              try {
                final bookProvider = Provider.of<BookProvider>(context, listen: false);
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                await bookProvider.addBook(
                  Book(
                    bookId: 0,
                    title: _titleController.text,
                    author: _authorController.text,
                    isbn: _isbnController.text,
                    category: _categoryController.text,
                    totalCopies: int.parse(_copiesController.text),
                    availableCopies: int.parse(_copiesController.text),
                  ),
                  authProvider.token!,
                );
                Navigator.pop(context);
                _titleController.clear();
                _authorController.clear();
                _isbnController.clear();
                _categoryController.clear();
                _copiesController.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Book added successfully!'),
                    backgroundColor: AppColors.accent,
                  ),
                );
              } catch (e) {
                if (e.toString().contains('Invalid token')) {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  await authProvider.logout();
                  Navigator.pushReplacementNamed(context, '/login');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding book: $e'),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: Text('Add', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _showQRScannerDialog() {
    showDialog(
      context: context,
      builder: (context) => FadeIn(
        duration: Duration(milliseconds: 300),
        child: AlertDialog(
          title: Text('Scan QR Code', style: GoogleFonts.poppins(color: AppColors.primary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 300,
                  height: 300,
                  color: Colors.black,
                  child: QRView(
                    key: _qrKey,
                    onQRViewCreated: _onQRViewCreated,
                    overlay: QrScannerOverlayShape(
                      borderColor: AppColors.accent,
                      borderRadius: 10,
                      borderLength: 30,
                      borderWidth: 10,
                      cutOutSize: 250,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Or enter QR code data manually:',
                  style: GoogleFonts.poppins(fontSize: 14, color: AppColors.primary),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _qrDataController,
                  decoration: InputDecoration(
                    labelText: 'QR Code JSON',
                    border: OutlineInputBorder(),
                    hintText: '{"user_id": 2, "book_id": 1, "action": "borrow/return"}',
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    if (_qrDataController.text.isNotEmpty) {
                      await _processQRData(_qrDataController.text);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please enter QR code data.'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                  child: Text('Process Manually', style: GoogleFonts.poppins()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _qrController?.stopCamera();
                Navigator.pop(context);
              },
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
        title: Text('CampusLib Admin Dashboard', style: GoogleFonts.poppins()),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Manage Books',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddBookDialog,
                    icon: Icon(Icons.add),
                    label: Text('Add Book', style: GoogleFonts.poppins()),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Expanded(
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
                                      title: Text(
                                        book.title,
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        'Author: ${book.author} | Category: ${book.category} | Available: ${book.availableCopies}/${book.totalCopies}',
                                        style: GoogleFonts.poppins(),
                                      ),
                                      trailing: IconButton(
                                        icon: Icon(Icons.delete, color: AppColors.error),
                                        onPressed: () async {
                                          setState(() {
                                            _isLoading = true;
                                          });
                                          try {
                                            await bookProvider.deleteBook(
                                              book.bookId,
                                              authProvider.token!,
                                            );
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Book deleted successfully!'),
                                                backgroundColor: AppColors.accent,
                                              ),
                                            );
                                          } catch (e) {
                                            if (e.toString().contains('Invalid token')) {
                                              await authProvider.logout();
                                              Navigator.pushReplacementNamed(context, '/login');
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error deleting book: $e'),
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
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Borrow Transactions',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showQRScannerDialog,
                    icon: Icon(Icons.qr_code_scanner),
                    label: Text('Scan QR', style: GoogleFonts.poppins()),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Expanded(
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
                        : transactionProvider.transactions.isEmpty
                            ? Center(child: Text('No transactions found', style: GoogleFonts.poppins()))
                            : ListView.builder(
                                itemCount: transactionProvider.transactions.length,
                                itemBuilder: (context, index) {
                                  final transaction = transactionProvider.transactions[index];
                                  return Card(
                                    elevation: 5,
                                    margin: EdgeInsets.symmetric(vertical: 10),
                                    child: ListTile(
                                      title: Text(
                                        'Transaction #${transaction.id}',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        'User ID: ${transaction.userId} | Book ID: ${transaction.bookId} | Date: ${transaction.borrowDate} | Status: ${transaction.status}${transaction.returnDate != null ? ' | Returned on: ${transaction.returnDate}' : ''}',
                                        style: GoogleFonts.poppins(),
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
    );
  }
}