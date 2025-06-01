import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/reader_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'providers/auth_provider.dart';
import 'providers/book_provider.dart';
import 'providers/transaction_provider.dart';

void main() {
  runApp(CampusLibApp());
}

class CampusLibApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BookProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'CampusLib',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        initialRoute: '/login',
        routes: {
          '/login': (context) => LoginScreen(),
          '/reader_dashboard': (context) => ReaderDashboard(),
          '/admin_dashboard': (context) => AdminDashboard(),
        },
      ),
    );
  }
}