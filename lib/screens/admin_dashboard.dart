import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/book_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/book.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _isbnController = TextEditingController();
  final _categoryController = TextEditingController();
  final _copiesController = TextEditingController();
  final _qrDataController = TextEditingController();
  final _readerNameController = TextEditingController();
  final _readerEmailController = TextEditingController();
  final _readerPasswordController = TextEditingController();
  final _libraryCardSearchController = TextEditingController();
  bool _isLoading = false;
  QRViewController? _qrController;
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  TabController? _tabController;
  Map<String, dynamic>? _searchedUser;
  double? _searchedUserTotalFine;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeData();
  }

  Future<void> _initializeData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) {
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

  void _showMarkAsPaidDialog(int userId, double totalFine) {
    showDialog(
      context: context,
      builder: (context) => FadeIn(
        duration: Duration(milliseconds: 300),
        child: AlertDialog(
          title: Text('Approve Fine Payment', style: GoogleFonts.poppins(color: AppColors.primary)),
          content: Text(
            'User $userId has requested to pay a fine of ${totalFine.toStringAsFixed(2)} rupees. Approve or reject this request?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                try {
                  setState(() {
                    _isLoading = true;
                  });
                  await transactionProvider.adminPayFine(authProvider.token!, userId, false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fine payment request rejected.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                } catch (e) {
                  if (e.toString().contains('Invalid token')) {
                    await authProvider.logout();
                    Navigator.pushReplacementNamed(context, '/login');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error rejecting payment: $e'),
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
              child: Text('Reject', style: GoogleFonts.poppins(color: AppColors.error)),
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
                  await transactionProvider.adminPayFine(authProvider.token!, userId, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fine payment approved!'),
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
                        content: Text('Error approving payment: $e'),
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
              child: Text('Approve', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
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

  void _showEditBookDialog(Book book) {
    // Pre-fill the text controllers with the book's current details
    _titleController.text = book.title;
    _authorController.text = book.author;
    _isbnController.text = book.isbn;
    _categoryController.text = book.category;
    _copiesController.text = book.totalCopies.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Book', style: GoogleFonts.poppins(color: AppColors.primary)),
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
                  labelText: 'Total Copies (Available: ${book.availableCopies})',
                  border: OutlineInputBorder(),
                  helperText: 'Note: Available copies will not change unless adjusted by transactions.',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _titleController.clear();
              _authorController.clear();
              _isbnController.clear();
              _categoryController.clear();
              _copiesController.clear();
              Navigator.pop(context);
            },
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.error)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTotalCopies = int.tryParse(_copiesController.text);
              if (newTotalCopies == null || newTotalCopies < book.availableCopies) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Total copies cannot be less than available copies (${book.availableCopies}).'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              setState(() {
                _isLoading = true;
              });
              try {
                final bookProvider = Provider.of<BookProvider>(context, listen: false);
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final updatedBook = Book(
                  bookId: book.bookId,
                  title: _titleController.text,
                  author: _authorController.text,
                  isbn: _isbnController.text,
                  category: _categoryController.text,
                  totalCopies: newTotalCopies,
                  availableCopies: book.availableCopies, // Preserve available copies
                );
                await bookProvider.updateBook(book.bookId, updatedBook, authProvider.token!);
                Navigator.pop(context);
                _titleController.clear();
                _authorController.clear();
                _isbnController.clear();
                _categoryController.clear();
                _copiesController.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Book updated successfully!'),
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
                      content: Text('Error updating book: $e'),
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
            child: Text('Update', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _showCreateReaderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create Reader Profile', style: GoogleFonts.poppins(color: AppColors.primary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _readerNameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _readerEmailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _readerPasswordController,
                decoration: InputDecoration(
                  labelText: 'Password (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'default123 if not provided',
                ),
                obscureText: true,
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
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final response = await http.post(
                  Uri.parse('http://localhost:5000/api/admin/create-reader'),
                  headers: {
                    'Authorization': 'Bearer ${authProvider.token}',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode({
                    'name': _readerNameController.text,
                    'email': _readerEmailController.text,
                    'password': _readerPasswordController.text.isNotEmpty ? _readerPasswordController.text : 'default123',
                  }),
                );
                final data = jsonDecode(response.body);
                if (response.statusCode == 201) {
                  Navigator.pop(context);
                  _readerNameController.clear();
                  _readerEmailController.clear();
                  _readerPasswordController.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reader created successfully! Library Card: ${data['library_card_no']}'),
                      backgroundColor: AppColors.accent,
                    ),
                  );
                } else {
                  throw Exception(data['message'] ?? 'Failed to create reader');
                }
              } catch (e) {
                if (e.toString().contains('Invalid token')) {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  await authProvider.logout();
                  Navigator.pushReplacementNamed(context, '/login');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error creating reader: $e'),
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
            child: Text('Create', style: GoogleFonts.poppins()),
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

  Future<void> _importBooksCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null || result.files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No file selected'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final file = result.files.first;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:5000/api/admin/import-books'),
      );
      request.headers['Authorization'] = 'Bearer ${authProvider.token}';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);

      if (response.statusCode == 200) {
        final bookProvider = Provider.of<BookProvider>(context, listen: false);
        await bookProvider.fetchBooks(authProvider.token!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']),
            backgroundColor: AppColors.accent,
          ),
        );
      } else {
        throw Exception(data['message'] ?? 'Failed to import books');
      }
    } catch (e) {
      if (e.toString().contains('Invalid token')) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.logout();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing books: $e'),
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

  Future<void> _searchLibraryCard() async {
    final libraryCardNo = _libraryCardSearchController.text.trim();
    if (libraryCardNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a library card number'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _searchedUser = null;
      _searchedUserTotalFine = null;
    });

    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await transactionProvider.fetchTransactionsByLibraryCard(authProvider.token!, libraryCardNo);

    setState(() {
      _isLoading = false;
      if (result != null) {
        _searchedUser = result['user'];
        _searchedUserTotalFine = result['total_fine'];
      }
    });
  }

  @override
  void dispose() {
    _qrController?.dispose();
    _tabController?.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    _categoryController.dispose();
    _copiesController.dispose();
    _qrDataController.dispose();
    _readerNameController.dispose();
    _readerEmailController.dispose();
    _readerPasswordController.dispose();
    _libraryCardSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = Provider.of<BookProvider>(context);
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CampusLib Admin Dashboard',
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
            Tab(text: 'Books'),
            Tab(text: 'Transactions'),
            Tab(text: 'Readers'),
            Tab(text: 'Import'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : TabBarView(
              controller: _tabController,
              children: [
                // Books Tab
                FadeIn(
                  duration: Duration(milliseconds: 500),
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Manage Books',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _showAddBookDialog,
                              icon: Icon(Icons.add),
                              label: Text('Add Book', style: GoogleFonts.poppins()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
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
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(Icons.edit, color: AppColors.primary),
                                                    onPressed: () {
                                                      _showEditBookDialog(book);
                                                    },
                                                    tooltip: 'Edit Book',
                                                  ),
                                                  IconButton(
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
                                                    tooltip: 'Delete Book',
                                                  ),
                                                ],
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
                // Transactions Tab
                FadeIn(
                  duration: Duration(milliseconds: 500),
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Borrow Transactions',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _showQRScannerDialog,
                              icon: Icon(Icons.qr_code_scanner),
                              label: Text('Scan QR', style: GoogleFonts.poppins()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Expanded(
                          child: transactionProvider.errorMessage != null
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
                                        final userTransactions = transactionProvider.transactions
                                            .where((t) => t.userId == transaction.userId && !t.finePaid && t.fine > 0 && t.paymentStatus == 'pending')
                                            .toList();
                                        final totalPendingFine = userTransactions.fold<double>(0.0, (sum, t) => sum + t.fine);

                                        return ZoomIn(
                                          duration: Duration(milliseconds: 300),
                                          child: Card(
                                            elevation: 5,
                                            margin: EdgeInsets.symmetric(vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(15),
                                            ),
                                            child: ExpansionTile(
                                              title: Text(
                                                'User ID: ${transaction.userId} | Book ID: ${transaction.bookId}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              subtitle: Text(
                                                'Status: ${transaction.status} | Fine: ${transaction.fine} rupees ',
                                                style: GoogleFonts.poppins(fontSize: 14),
                                              ),
                                              children: [
                                                Padding(
                                                  padding: EdgeInsets.all(16.0),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Borrow Date: ${transaction.borrowDate}',
                                                        style: GoogleFonts.poppins(fontSize: 14),
                                                      ),
                                                      Text(
                                                        'Due Date: ${transaction.dueDate}',
                                                        style: GoogleFonts.poppins(fontSize: 14),
                                                      ),
                                                      if (transaction.returnDate != null)
                                                        Text(
                                                          'Return Date: ${transaction.returnDate}',
                                                          style: GoogleFonts.poppins(fontSize: 14),
                                                        ),
                                                      Text(
                                                        'Fine Paid: ${transaction.finePaid ? 'Yes' : 'No'}',
                                                        style: GoogleFonts.poppins(fontSize: 14),
                                                      ),
                                                      if (transaction.paymentStatus != null)
                                                        Text(
                                                          'Payment Status: ${transaction.paymentStatus}',
                                                          style: GoogleFonts.poppins(fontSize: 14),
                                                        ),
                                                      if (totalPendingFine > 0 && transaction.paymentStatus == 'pending')
                                                        Padding(
                                                          padding: EdgeInsets.only(top: 10),
                                                          child: ElevatedButton(
                                                            onPressed: () => _showMarkAsPaidDialog(
                                                              transaction.userId,
                                                              totalPendingFine,
                                                            ),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: AppColors.accent,
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(12),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              'Process Fine Payment (${totalPendingFine.toStringAsFixed(2)} rupees)',
                                                              style: GoogleFonts.poppins(),
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
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
                // Readers Tab
                FadeIn(
                  duration: Duration(milliseconds: 500),
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Manage Readers',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _showCreateReaderDialog,
                              icon: Icon(Icons.person_add),
                              label: Text('Create Reader', style: GoogleFonts.poppins()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _libraryCardSearchController,
                                decoration: InputDecoration(
                                  labelText: 'Search by Library Card Number',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: Icon(Icons.search),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _searchLibraryCard,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text('Search', style: GoogleFonts.poppins()),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Expanded(
                          child: transactionProvider.errorMessage != null
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
                                        onPressed: _searchLibraryCard,
                                        child: Text('Retry', style: GoogleFonts.poppins()),
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                                      ),
                                    ],
                                  ),
                                )
                              : _searchedUser == null
                                  ? Center(child: Text('Search for a reader above', style: GoogleFonts.poppins()))
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Card(
                                          elevation: 5,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(15),
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Reader Details',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                                SizedBox(height: 10),
                                                Text('Name: ${_searchedUser!['name']}', style: GoogleFonts.poppins()),
                                                Text('Email: ${_searchedUser!['email']}', style: GoogleFonts.poppins()),
                                                Text('Library Card: ${_searchedUser!['library_card_no']}', style: GoogleFonts.poppins()),
                                                Text('Total Fine: ${_searchedUserTotalFine?.toStringAsFixed(2) ?? '0.00'}', style: GoogleFonts.poppins()),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'Transactions',
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        SizedBox(height: 10),
                                        Expanded(
                                          child: transactionProvider.transactions.isEmpty
                                              ? Center(child: Text('No transactions found', style: GoogleFonts.poppins()))
                                              : ListView.builder(
                                                  itemCount: transactionProvider.transactions.length,
                                                  itemBuilder: (context, index) {
                                                    final transaction = transactionProvider.transactions[index];
                                                    return Card(
                                                      elevation: 3,
                                                      margin: EdgeInsets.symmetric(vertical: 5),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      child: ListTile(
                                                        title: Text(
                                                          'Book ID: ${transaction.bookId}',
                                                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                                        ),
                                                        subtitle: Text(
                                                          'Status: ${transaction.status}\nFine: ${transaction.fine}',
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
                      ],
                    ),
                  ),
                ),
                // Import Tab
                FadeIn(
                  duration: Duration(milliseconds: 500),
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import Books via CSV',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Upload a CSV file with the following headers: title, author, isbn, category, total_copies',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        SizedBox(height: 20),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _importBooksCsv,
                            icon: Icon(Icons.upload_file),
                            label: Text('Upload CSV', style: GoogleFonts.poppins()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
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