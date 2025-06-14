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

class _ReaderDashboardState extends State<ReaderDashboard> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = false;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  void _showPaymentRequestDialog(double totalFine) {
    showDialog(
      context: context,
      builder: (context) => FadeIn(
        duration: Duration(milliseconds: 300),
        child: AlertDialog(
          title: Text(
            'Request Fine Payment',
            style: GoogleFonts.poppins(color: AppColors.primary),
          ),
          content: Text(
            'You have a fine of ${totalFine.toStringAsFixed(2)} rupees. Request admin approval to pay this fine?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.error)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                try {
                  setState(() {
                    _isLoading = true;
                  });
                  await transactionProvider.requestFinePayment(authProvider.token!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fine payment request submitted! Awaiting admin approval.'),
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
                        content: Text('Error requesting payment: $e'),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Request', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = Provider.of<BookProvider>(context);
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    // Check for pending payment requests
    final hasPendingRequest = transactionProvider.transactions.any(
      (t) => !t.finePaid && t.fine > 0 && t.paymentStatus == 'pending',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CampusLib Reader Dashboard',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await authProvider.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.accent,
          tabs: [
            Tab(text: 'Browse Books'),
            Tab(text: 'My Borrowed Books'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : TabBarView(
              controller: _tabController,
              children: [
                // Browse Books Tab
                FadeIn(
                  duration: Duration(milliseconds: 500),
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (transactionProvider.totalFine > 0 || hasPendingRequest)
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
                                    hasPendingRequest
                                        ? 'Your fine payment request is pending admin approval.'
                                        : 'You have an overdue fine of ${transactionProvider.totalFine.toStringAsFixed(2)} rupees. Request admin approval to pay.',
                                    style: GoogleFonts.poppins(color: AppColors.error, fontSize: 14),
                                  ),
                                ),
                                if (!hasPendingRequest)
                                  ElevatedButton(
                                    onPressed: () {
                                      _showPaymentRequestDialog(transactionProvider.totalFine);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text('Request Payment', style: GoogleFonts.poppins()),
                                  ),
                              ],
                            ),
                          ),
                        Text(
                          'Browse Books',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  labelText: 'Search by Title or Author',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: Icon(Icons.search, color: AppColors.accent),
                                ),
                                style: GoogleFonts.poppins(),
                                onChanged: (value) async {
                                  try {
                                    await bookProvider.fetchBooks(
                                      authProvider.token!,
                                      query: value,
                                      category: _selectedCategory ?? '',
                                    );
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
                                  await bookProvider.fetchBooks(
                                    authProvider.token!,
                                    query: _searchController.text,
                                    category: value ?? '',
                                  );
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
                        SizedBox(height: 16),
                        Expanded(
                          child: bookProvider.errorMessage != null
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
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.accent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
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
                                        return ZoomIn(
                                          duration: Duration(milliseconds: 300),
                                          child: Card(
                                            elevation: 5,
                                            margin: EdgeInsets.symmetric(vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(15),
                                            ),
                                            child: ListTile(
                                              contentPadding: EdgeInsets.all(16),
                                              title: Text(
                                                book.title,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              subtitle: Text(
                                                'Author: ${book.author}\nCategory: ${book.category}\nAvailable: ${book.availableCopies}/${book.totalCopies}',
                                                style: GoogleFonts.poppins(fontSize: 14),
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
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                      ),
                                                      child: Text('Borrow', style: GoogleFonts.poppins()),
                                                    )
                                                  : Text(
                                                      'Not Available',
                                                      style: GoogleFonts.poppins(color: AppColors.error),
                                                    ),
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
                // My Borrowed Books Tab
                FadeIn(
                  duration: Duration(milliseconds: 500),
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (transactionProvider.totalFine > 0 || hasPendingRequest)
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
                                    hasPendingRequest
                                        ? 'Your fine payment request is pending admin approval.'
                                        : 'You have an overdue fine of ${transactionProvider.totalFine.toStringAsFixed(2)}. Request admin approval to pay.',
                                    style: GoogleFonts.poppins(color: AppColors.error, fontSize: 14),
                                  ),
                                ),
                                if (!hasPendingRequest)
                                  ElevatedButton(
                                    onPressed: () {
                                      _showPaymentRequestDialog(transactionProvider.totalFine);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text('Request Payment', style: GoogleFonts.poppins()),
                                  ),
                              ],
                            ),
                          ),
                        Text(
                          'My Borrowed Books',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 16),
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
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.accent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
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
                                            return ZoomIn(
                                              duration: Duration(milliseconds: 300),
                                              child: Card(
                                                elevation: 5,
                                                margin: EdgeInsets.symmetric(vertical: 8),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(15),
                                                ),
                                                child: ListTile(
                                                  contentPadding: EdgeInsets.all(16),
                                                  title: Text(
                                                    book.title,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                  subtitle: Text(
                                                    'Author: ${book.author}\nBorrowed on: ${transaction.borrowDate}\nDue: ${transaction.dueDate ?? 'N/A'}\nFine: ${transaction.fine.toStringAsFixed(2)}${transaction.finePaid ? ' (Paid)' : transaction.paymentStatus != null ? ' (${transaction.paymentStatus})' : ''}',
                                                    style: GoogleFonts.poppins(fontSize: 14),
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
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppColors.accent,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                    ),
                                                    child: Text('Return', style: GoogleFonts.poppins()),
                                                  ),
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
              ],
            ),
    );
  }
}