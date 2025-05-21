
# CampusLib - Library Management System

## Overview
CampusLib is a library management system designed to streamline book borrowing and returning processes for university libraries. It features a Flask backend and a Flutter frontend, providing distinct interfaces for readers (students) and admins (librarians). Key functionalities include user authentication, book management, transaction tracking (borrow/return), and QR code scanning for seamless transactions.

## Features
- **User Authentication**: Secure login and registration for readers and admins using JWT.
- **Book Management**: Admins can add, update, and delete books; readers can browse and search books.
- **Borrowing & Returning**: Readers can request to borrow books via QR codes; admins can confirm transactions by scanning QR codes.
- **Transaction History**: Track borrowing and returning history for both readers and admins.
- **Responsive UI**: Built with Flutter for a smooth cross-platform experience.

## Tech Stack
- **Backend**: Flask (Python), MySQL, Flask-JWT-Extended for authentication
- **Frontend**: Flutter (Dart)
- **Dependencies**:
  - **Backend**: `flask`, `flask-jwt-extended`, `flask-cors`, `mysql-connector-python`, `bcrypt`
  - **Frontend**: `http`, `provider`, `flutter_secure_storage`, `qr_code_scanner`, `qr_flutter`, `google_fonts`, `animate_do`

## Project Structure
```
CampusLib/
├── app.py                    # Flask backend server
├── lib/
│   ├── constants/
│   │   └── app_colors.dart   # App-wide constants (colors, API base URL)
│   ├── models/
│   │   ├── book.dart         # Book model
│   │   ├── user.dart         # User model
│   │   └── transaction.dart  # Transaction model
│   ├── providers/
│   │   ├── auth_provider.dart     # Manages authentication state
│   │   ├── book_provider.dart     # Manages book-related operations
│   │   └── transaction_provider.dart # Manages transaction operations
│   ├── screens/
│   │   ├── login_screen.dart      # Login screen for users
│   │   ├── admin_dashboard.dart   # Admin dashboard for managing books and transactions
│   │   └── reader_dashboard.dart  # Reader dashboard for browsing and borrowing books
├── pubspec.yaml              # Flutter dependencies
└── README.md                 # Project documentation
```

## Prerequisites
- Python 3.8+ (for the backend)
- Flutter 3.0+ (for the frontend)
- MySQL (for the database)
- Git (for version control)
- A code editor like VS Code or IntelliJ IDEA

## Setup Instructions

### 1. Clone the Repository
```bash
git clone https://github.com/username/campuslib.git
cd campuslib
```

### 2. Backend Setup (Flask)
- Install Python dependencies:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install flask flask-jwt-extended flask-cors mysql-connector-python bcrypt
```
- Create MySQL database:
```sql
CREATE DATABASE campuslib;
```
- Update `app.py` configuration:
```python
db_config = {
    'host': 'localhost',
    'user': 'root',
    'password': 'Jaiho@123',
    'database': 'campuslib'
}
```
- Create tables in MySQL:
```sql
USE campuslib;

CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    library_card_no VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    user_type ENUM('reader', 'admin') DEFAULT 'reader'
);

CREATE TABLE books (
    book_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    author VARCHAR(255) NOT NULL,
    isbn VARCHAR(13) NOT NULL,
    category VARCHAR(50) NOT NULL,
    total_copies INT NOT NULL,
    available_copies INT NOT NULL
);

CREATE TABLE borrow_transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    book_id INT NOT NULL,
    borrow_date DATETIME NOT NULL,
    return_date DATETIME,
    status ENUM('borrowed', 'returned') DEFAULT 'borrowed',
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (book_id) REFERENCES books(book_id)
);
```
- Run Flask server:
```bash
python app.py
```

### 3. Frontend Setup (Flutter)
- Install Flutter dependencies:
```bash
flutter pub get
```
- Run the app:
```bash
flutter run
```
> Note: If using a physical device, update API base URL in `lib/constants/app_colors.dart`

## Usage

### 1. Register/Login
- Choose Reader or Admin mode
- Use `/api/register` via Postman to register:
```json
POST http://localhost:5000/api/register
{
    "name": "John Doe",
    "email": "john@example.com",
    "library_card_no": "LIB123",
    "password": "password123",
    "user_type": "reader"
}
```

### 2. Reader Dashboard
- Browse/search books
- Request to borrow via QR
- Show QR to admin to confirm
- View and return books

### 3. Admin Dashboard
- Add, update, delete books
- Scan QR codes to confirm transactions
- View all transactions

## API Endpoints
- `POST /api/register`: Register a new user
- `POST /api/login`: Authenticate and get JWT token
- `GET /api/books`: Fetch all books
- `POST /api/books`: Add a new book (admin)
- `DELETE /api/books/:id`: Delete a book (admin)
- `GET /api/categories`: Get all categories
- `POST /api/borrow/request`: Borrow request
- `POST /api/borrow/confirm`: Confirm borrow (admin)
- `POST /api/return/confirm`: Confirm return (admin)
- `GET /api/transactions`: All transactions (admin)
- `GET /api/user/transactions`: Reader's transactions

## Known Issues
- API calls use `localhost` (won’t work on physical devices without IP update)
- CORS allows all origins (restrict in production)

## Recent Changes
- Fixed JWT Subject Error (user_id to string)
- Fixed Flutter setState error with `addPostFrameCallback`

## Contributing
```bash
fork → branch → commit → push → pull request
```

## License
MIT License - see LICENSE

## Contact
For support, contact: sumanthd032@gmail.com