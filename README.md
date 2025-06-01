# CampusLib Library Management System

## Overview
CampusLib is a modern library management system designed for university libraries, enabling efficient book borrowing, returning, and fine management. Built with a Flutter frontend, Flask backend, and MySQL database, it supports two user roles: Readers (students/faculty) and Admins (librarians). The system leverages QR code-based workflows for seamless transactions and enforces role-based access control using JWT authentication.

**Purpose:** Streamline library operations with a user-friendly, cross-platform app.  
**Technologies:**
- **Frontend:** Flutter (Dart) - Cross-platform mobile app
- **Backend:** Flask (Python) - RESTful API
- **Database:** MySQL - Relational data storage
- **Security:** JWT (`flask_jwt_extended`), `bcrypt` for password hashing
- **Libraries:** `qr_flutter`, `qr_code_scanner`, `animate_do`, `google_fonts`

## Features

### For Readers
- **Browse Books:** Search and filter books by title, author, or category.
- **Borrow/Return Books:** Use QR codes to request and confirm borrowing/returning.
- **Transaction History:** View borrowing history with fines.
- **Fine Management:** Request payment for overdue fines ($1/day after 14 days).

### For Admins
- **User Management:** Create reader accounts, view user transactions.
- **Book Management:** Add, edit, delete, and import books via CSV.
- **Transaction Management:** Confirm borrow/return requests via QR scanning.
- **Fine Approval:** Approve or reject fine payment requests.

### General Features
- **QR Code Workflow:** Simplifies borrow/return confirmation.
- **Modern UI:** Animations, custom fonts (`GoogleFonts.poppins`), gradient themes.
- **Security:** Role-based access with JWT, password hashing with bcrypt.

## Prerequisites
- Flutter SDK (v3.0 or later)
- Python (v3.8 or later)
- MySQL (v8.0 or later)
- Node.js (optional)
- Git

## Setup Instructions

### 1. Clone the Repository
```bash
git clone https://github.com/username/campuslib.git
cd campuslib
```

### 2. Backend Setup (Flask)

#### Navigate:
```bash
cd backend
```

#### Create and activate virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

#### Install dependencies:
```bash
pip install -r requirements.txt
```

#### Set environment variables in `.env`:
```
DB_HOST=localhost
DB_USER=your_username
DB_PASSWORD=your_password
DB_NAME=campuslib_db
JWT_SECRET_KEY=your_jwt_secret_key
PORT=5000
```

#### Set up MySQL database:
```sql
CREATE DATABASE campuslib_db;

CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    library_card_no VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    user_type ENUM('reader', 'admin') NOT NULL
);

CREATE TABLE books (
    book_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    author VARCHAR(255) NOT NULL,
    isbn VARCHAR(13) UNIQUE NOT NULL,
    category VARCHAR(50) NOT NULL,
    total_copies INT NOT NULL,
    available_copies INT NOT NULL
);

CREATE TABLE borrow_transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    book_id INT NOT NULL,
    borrow_date DATETIME NOT NULL,
    due_date DATETIME NOT NULL,
    return_date DATETIME,
    status ENUM('borrowed', 'returned') NOT NULL,
    fine DECIMAL(10,2) DEFAULT 0,
    fine_paid DECIMAL(10,2) DEFAULT 0,
    payment_status ENUM('pending', 'approved', 'rejected'),
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (book_id) REFERENCES books(book_id)
);
```

#### Insert default admin user:
```sql
INSERT INTO users (name, email, library_card_no, password, user_type)
VALUES ('Admin', 'admin@university.com', 'ADMIN-001', '<hashed_password>', 'admin');
```

> Generate bcrypt hash:
```python
import bcrypt
print(bcrypt.hashpw("admin123".encode('utf-8'), bcrypt.gensalt()).decode('utf-8'))
```

#### Run the backend:
```bash
python app.py
```

### 3. Frontend Setup (Flutter)

```bash
cd frontend
flutter pub get
```

#### Configure API URL in `frontend/lib/constants/colors.dart`:
```dart
const String baseUrl = 'http://localhost:5000/api';
```

#### Run the app:
```bash
flutter run
```

## Usage

### Reader
- Login using library card number and password
- Browse books
- Borrow/return using QR codes
- View transaction history
- Request fine payments

### Admin
- Login using email/password
- Manage readers, books, and transactions
- Scan QR codes to confirm actions
- Approve/reject fines

## API Endpoints

### Authentication
- `POST /api/register`
- `POST /api/login`

### Books
- `GET /api/books`
- `POST /api/books`
- `PUT /api/books/<book_id>`
- `DELETE /api/books/<book_id>`

### Transactions
- `POST /api/borrow/request`
- `POST /api/borrow/confirm`
- `POST /api/return/request`
- `POST /api/return/confirm`
- `GET /api/user/transactions`
- `GET /api/transactions`

### Fines
- `POST /api/request-fine-payment`
- `POST /api/admin/pay-fine`

### Admin
- `POST /api/admin/create-reader`
- `POST /api/admin/import-books`

## Security
- JWT-based authentication
- Role-based access control
- Password hashing with bcrypt
- Input validation & error handling

## Future Enhancements
- Push notifications
- Analytics dashboard
- Soft deletion
- Multi-language support

## Contributing
1. Fork the repository.
2. Create a new branch:
```bash
git checkout -b feature-branch
```
3. Commit changes:
```bash
git commit -m "Add feature"
```
4. Push and create a pull request:
```bash
git push origin feature-branch
```

## License
Educational purposes only.

## Contact
For issues or inquiries, contact the project maintainer.