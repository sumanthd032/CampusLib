from flask import Flask, request, jsonify
from flask_jwt_extended import JWTManager, jwt_required, create_access_token, get_jwt_identity, get_jwt
from flask_cors import CORS
import mysql.connector
from mysql.connector import Error
import bcrypt
from datetime import datetime, timedelta
import logging
import random
import string
import csv
from io import StringIO

app = Flask(__name__)
app.config['JWT_SECRET_KEY'] = '0afce35125fb4100282bae99fcd6c8eb'
jwt = JWTManager(app)

CORS(app, resources={r"/api/*": {"origins": "*"}})

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

db_config = {
    'host': 'localhost',
    'user': 'root',
    'password': 'Jaiho@123',
    'database': 'campuslib'
}

FINE_PER_DAY = 1.0
BORROW_PERIOD_DAYS = 14

def generate_library_card_number():
    date_part = datetime.now().strftime('%Y%m%d')
    random_part = ''.join(random.choices(string.digits, k=4))
    return f"LIB-{date_part}-{random_part}"

def calculate_fine(borrow_date, due_date, return_date, status, fine_paid):
    if fine_paid:
        return 0.0

    today = datetime.now()
    due_date = datetime.strptime(due_date, '%Y-%m-%d %H:%M:%S') if isinstance(due_date, str) else due_date

    if status == 'returned' and return_date:
        return_date = datetime.strptime(return_date, '%Y-%m-%d %H:%M:%S') if isinstance(return_date, str) else return_date
        if return_date <= due_date:
            return 0.0
        overdue_days = (return_date - due_date).days
    else:
        if today <= due_date:
            return 0.0
        overdue_days = (today - due_date).days

    fine = overdue_days * FINE_PER_DAY
    return round(fine, 2)

@app.route('/api/register', methods=['POST'])
def register():
    try:
        data = request.get_json()
        name = data.get('name')
        email = data.get('email')
        library_card_no = data.get('library_card_no')
        password = data.get('password')
        user_type = data.get('user_type', 'reader')

        if not all([name, email, library_card_no, password]):
            logger.warning("Registration failed: Missing required fields")
            return jsonify({"status": "error", "message": "Missing required fields"}), 400

        hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor()

        cursor.execute(
            "INSERT INTO users (name, email, library_card_no, password, user_type) VALUES (%s, %s, %s, %s, %s)",
            (name, email, library_card_no, hashed_password, user_type)
        )
        connection.commit()
        logger.info(f"User registered: {email}, Type: {user_type}")
        return jsonify({"status": "success", "message": "User registered successfully"}), 201
    except Error as e:
        logger.error(f"Database error during registration: {e}")
        return jsonify({"status": "error", "message": f"Database error: {e}"}), 500
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/api/admin/create-reader', methods=['POST'])
@jwt_required()
def create_reader():
    identity = get_jwt_identity()
    claims = get_jwt()
    if claims['user_type'] != 'admin':
        logger.warning(f"Create reader failed: Admin access required for user {identity}")
        return jsonify({"status": "error", "message": "Admin access required"}), 403

    try:
        data = request.get_json()
        name = data.get('name')
        email = data.get('email')
        password = data.get('password', 'default123')

        if not all([name, email]):
            logger.warning("Create reader failed: Missing required fields")
            return jsonify({"status": "error", "message": "Missing required fields"}), 400

        library_card_no = generate_library_card_number()
        hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor()

        cursor.execute("SELECT * FROM users WHERE email = %s OR library_card_no = %s", (email, library_card_no))
        if cursor.fetchone():
            logger.warning(f"Create reader failed: Email {email} or library card {library_card_no} already exists")
            return jsonify({"status": "error", "message": "Email or library card number already exists"}), 400

        cursor.execute(
            "INSERT INTO users (name, email, library_card_no, password, user_type) VALUES (%s, %s, %s, %s, %s)",
            (name, email, library_card_no, hashed_password, 'reader')
        )
        connection.commit()
        logger.info(f"Reader created: {email}, Library Card: {library_card_no}")
        return jsonify({
            "status": "success",
            "message": "Reader created successfully",
            "library_card_no": library_card_no
        }), 201
    except Error as e:
        logger.error(f"Database error during reader creation: {e}")
        return jsonify({"status": "error", "message": f"Database error: {e}"}), 500
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/api/admin/user-transactions', methods=['GET'])
@jwt_required()
def get_user_transactions_by_library_card():
    identity = get_jwt_identity()
    claims = get_jwt()
    if claims['user_type'] != 'admin':
        logger.warning(f"Fetch user transactions failed: Admin access required for user {identity}")
        return jsonify({"status": "error", "message": "Admin access required"}), 403

    try:
        library_card_no = request.args.get('library_card_no')
        if not library_card_no:
            logger.warning("Fetch user transactions failed: Library card number required")
            return jsonify({"status": "error", "message": "Library card number required"}), 400

        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor(dictionary=True)

        cursor.execute("SELECT * FROM users WHERE library_card_no = %s", (library_card_no,))
        user = cursor.fetchone()
        if not user:
            logger.warning(f"User not found with library card: {library_card_no}")
            return jsonify({"status": "error", "message": "User not found"}), 404

        cursor.execute("SELECT * FROM borrow_transactions WHERE user_id = %s", (user['user_id'],))
        transactions = cursor.fetchall()

        total_fine = 0.0
        for transaction in transactions:
            fine = calculate_fine(
                transaction['borrow_date'],
                transaction['due_date'],
                transaction['return_date'],
                transaction['status'],
                transaction['fine_paid']
            )
            if fine != float(transaction['fine']):
                cursor.execute(
                    "UPDATE borrow_transactions SET fine = %s WHERE id = %s",
                    (fine, transaction['id'])
                )
            transaction['fine'] = fine
            if not transaction['fine_paid'] and transaction['payment_status'] != 'pending':
                total_fine += fine
            transaction['fine_paid'] = bool(transaction['fine_paid'])
            transaction['payment_status'] = transaction['payment_status'] if transaction['payment_status'] else None

        connection.commit()
        logger.info(f"Fetched {len(transactions)} transactions for library card {library_card_no}, Total Fine: ${total_fine}")
        return jsonify({
            "status": "success",
            "user": {
                "user_id": user['user_id'],
                "name": user['name'],
                "email": user['email'],
                "library_card_no": user['library_card_no']
            },
            "transactions": transactions,
            "total_fine": total_fine
        }), 200
    except Error as e:
        logger.error(f"Database error fetching user transactions: {e}")
        return jsonify({"status": "error", "message": f"Database error: {e}"}), 500
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/api/admin/import-books', methods=['POST'])
@jwt_required()
def import_books():
    identity = get_jwt_identity()
    claims = get_jwt()
    if claims['user_type'] != 'admin':
        logger.warning(f"Import books failed: Admin access required for user {identity}")
        return jsonify({"status": "error", "message": "Admin access required"}), 403

    try:
        if 'file' not in request.files:
            logger.warning("Import books failed: No file uploaded")
            return jsonify({"status": "error", "message": "No file uploaded"}), 400

        file = request.files['file']
        if not file.filename.endswith('.csv'):
            logger.warning("Import books failed: File must be a CSV")
            return jsonify({"status": "error", "message": "File must be a CSV"}), 400

        # Read the CSV file
        content = file.read().decode('utf-8')
        csv_reader = csv.DictReader(StringIO(content))
        required_headers = ['title', 'author', 'isbn', 'category', 'total_copies']

        # Validate headers
        if not all(header in csv_reader.fieldnames for header in required_headers):
            missing = [header for header in required_headers if header not in csv_reader.fieldnames]
            logger.warning(f"Import books failed: Missing CSV headers: {missing}")
            return jsonify({"status": "error", "message": f"Missing CSV headers: {missing}"}), 400

        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor()

        books_added = 0
        for row in csv_reader:
            try:
                total_copies = int(row['total_copies'])
                # Check for duplicate ISBN
                cursor.execute("SELECT * FROM books WHERE isbn = %s", (row['isbn'],))
                if cursor.fetchone():
                    logger.warning(f"Skipping book with duplicate ISBN: {row['isbn']}")
                    continue
                cursor.execute(
                    "INSERT INTO books (title, author, isbn, category, total_copies, available_copies) VALUES (%s, %s, %s, %s, %s, %s)",
                    (row['title'], row['author'], row['isbn'], row['category'], total_copies, total_copies)
                )
                books_added += 1
            except (ValueError, KeyError) as e:
                logger.warning(f"Skipping invalid row: {row}, Error: {e}")
                continue

        connection.commit()
        logger.info(f"Imported {books_added} books by admin {identity}")
        return jsonify({"status": "success", "message": f"Imported {books_added} books successfully"}), 200
    except Error as e:
        logger.error(f"Database error during book import: {e}")
        return jsonify({"status": "error", "message": f"Database error: {e}"}), 500
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/api/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        identifier = data.get('identifier')
        password = data.get('password')

        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            "SELECT * FROM users WHERE email = %s OR library_card_no = %s",
            (identifier, identifier)
        )
        user = cursor.fetchone()

        if user and bcrypt.checkpw(password.encode('utf-8'), user['password'].encode('utf-8')):
            access_token = create_access_token(identity=str(user['user_id']), additional_claims={"user_type": user['user_type']})
            logger.info(f"User logged in: {identifier}, Type: {user['user_type']}")
            return jsonify({"status": "success", "token": access_token, "user_type": user['user_type']}), 200
        else:
            logger.warning(f"Login failed: Invalid credentials for {identifier}")
            return jsonify({"status": "error", "message": "Invalid credentials"}), 401
    except Error as e:
        logger.error(f"Database error during login: {e}")
        return jsonify({"status": "error", "message": f"Database error: {e}"}), 500
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/api/books', methods=['GET'])
@jwt_required()
def get_books():
    try:
        query = request.args.get('query', '')
        category = request.args.get('category', '')

        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor(dictionary=True)

        sql = "SELECT * FROM books WHERE 1=1"
        params = []
        if query:
            sql += " AND (title LIKE %s OR author LIKE %s)"
            params.extend([f"%{query}%", f"%{query}%"])
        if category:
            sql += " AND category = %s"
            params.append(category)

        cursor.execute(sql, params)
        books = cursor.fetchall()
        logger.info(f"Fetched {len(books)} books for query: {query}, category: {category}")
        return jsonify({"status": "success", "books": books}), 200
    except Error as e:
        logger.error(f"Database error fetching books: {e}")
        return jsonify({"status": "error", "message": f"Database error: {e}"}), 500
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/api/books', methods=['POST'])
@jwt_required()
def add_book():
    identity = get_jwt_identity()
    claims = get_jwt()
    if claims['user_type'] != 'admin':
        logger.warning(f"Add book failed: Admin access required for user {identity}")
        return jsonify({"status": "error", "message": "Admin access required"}), 403

    try:
        data = request.get_json()
        title = data.get('title')
        author = data.get('author')
        isbn = data.get('isbn')
        category = data.get('category')
        total_copies = data.get('total_copies')

        if not all([title, author, isbn, category, total_copies]):
            logger.warning("Add book failed: Missing required fields")
            return jsonify({"status": "error", "message": "Missing required fields"}), 400

        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor()

        # Check for duplicate ISBN
        cursor.execute("SELECT * FROM books WHERE isbn = %s", (isbn,))
        if cursor.fetchone():
            logger.warning(f"Add book failed: ISBN {isbn} already exists")
            return jsonify({"status": "error", "message": "ISBN already exists"}), 400

        cursor.execute(
            "INSERT INTO books (title, author, isbn, category, total_copies, available_copies) VALUES (%s, %s, %s, %s, %s, %s)",
            (title, author, isbn, category, total_copies, total_copies)
        )
        connection.commit()
        logger.info(f"Book added: {title} by {author}")
        return jsonify({"status": "success", "message": "Book added successfully"}), 201
    except Error as e:
        logger.error(f"Database error adding book: {e}")
        return jsonify({"status": "error", "message": f"Database error: {e}"}), 500
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/api/books/<int:book_id>', methods=['PUT'])
@jwt_required()
def update_book(book_id):
    identity = get_jwt_identity()
    claims = get_jwt()
    if claims['user_type'] != 'admin':
        logger.warning(f"Update book failed: Admin access required for user {identity}")
        return jsonify({"status": "error", "message": "Admin access required"}), 403

    try:
        data = request.get_json()
        title = data.get('title')
        author = data.get('author')
        isbn = data.get('isbn')
        category = data.get('category')
        total_copies = data.get('total_copies')

        if not all([title, author, isbn, category, total_copies]):
            logger.warning("Update book failed: Missing required fields")
            return jsonify({"status": "error", "message": "Missing required fields"}), 400

        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor(dictionary=True)

        # Fetch the current book to validate total_copies and check for duplicate ISBN
        cursor.execute("SELECT * FROM books WHERE book_id = %s", (book_id,))
        book = cursor.fetchone()
        if not book:
            logger.warning(f"Update book failed: Book {book_id} not found")
            return jsonify({"status": "error", "message": "Book not found"}), 404

        # Validate total_copies against available_copies
        if total_copies < book['available_copies']:
            logger.warning(f"Update book failed: Total copies {total_copies} cannot be less than available copies {book['available_copies']}")
            return jsonify({"status": "error", "message": f"Total copies cannot be less than available copies ({book['available_copies']})"}), 400

        # Check for duplicate ISBN (excluding the current book)
        cursor.execute("SELECT * FROM books WHERE isbn = %s AND book_id != %s", (isbn, book_id))
        if cursor.fetchone():
            logger.warning(f"Update book failed: ISBN {isbn} already exists")
            return jsonify({"status": "error", "message": "ISBN already exists"}), 400

        # Update the book
        cursor.execute(
            "UPDATE books SET title = %s, author = %s, isbn = %s, category = %s, total_copies = %s WHERE book_id = %s",
            (title, author, isbn, category, total_copies, book_id)
        )
        if cursor.rowcount == 0:
            logger.warning(f"Update book failed: Book {book_id} not updated")
            return jsonify({"status": "error", "message": "Book not updated"}), 500

        connection.commit()
        logger.info(f"Book updated: {book_id}, Title: {title}")
        return jsonify({"status": "success", "message": "Book updated successfully"}), 200
    except Error as e:
        logger.error(f"Database error updating book: {e}")
        return jsonify({"status": "error", "message": f"Database error: {e}"}), 500
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/api/books/<int:book_id>', methods=['DELETE'])
@jwt_required()
def delete_book(book_id):
    identity = get_jwt_identity()
    claims = get_jwt()
    if claims['user_type'] != 'admin':
        logger.warning(f"Delete book failed: Admin access required for user {identity}")
        return jsonify({"status": "error", "message": "Admin access required"}), 403

    try:
        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor()

        cursor.execute("DELETE FROM books WHERE book_id = %s", (book_id,))
        if cursor.rowcount == 0:
            logger.warning(f"Delete book failed: Book {book_id} not found")
            return jsonify({"status": "error", "message": "Book not found"}), 404

        connection.commit()
        logger.info(f"Book deleted: {book_id}")
        return jsonify({"status": "success", "message": "Book deleted successfully"}), 200
    except Error as e:
        logger.error(f"Database error deleting book: {e}")
        return jsonify({"status": "error", "message": f"Database error: {e}"}), 500
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/api/categories', methods=['GET'])
@jwt_required()
def get_categories():
    try:
        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor()

        cursor.execute("SELECT DISTINCT category FROM books")
        categories = [row[0] for row in cursor.fetchall()]
        logger.info(f"Fetched {len(categories)} categories")
        return jsonify({"status": "success", "categories": categories}), 200
    except Error as e:
        logger.error(f"Database error fetching categories: {e}")
        return jsonify({"status": "error", "message": f"Database error: {e}"}), 500
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/api/borrow/request', methods=['POST'])
@jwt_required()
def request_borrow():
    identity = get_jwt_identity()
    claims = get_jwt()
    if claims['user_type'] != 'reader':
        logger.warning(f"Borrow request failed: Reader access required for user {identity}")
        return jsonify({"status": "error", "message": "Reader access required"}), 403

    try:
        data = request.get_json()
        book_id = data.get('book_id')

        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor(dictionary=True)

        cursor.execute("SELECT * FROM books WHERE book_id = %s AND available_copies > 0", (book_id,))
        book = cursor.fetchone()
        if not book:
            logger.warning(f"Borrow request failed: Book {book_id} not available")
            return jsonify({"status": "error", "message": "Book not available"}), 404

        qr_data = {
            "user_id": identity,
            "book_id": book_id,
            "action": "borrow"
        }
        logger.info(f"Borrow request generated for user {identity}, book {book_id}")
        return jsonify({"status": "success", "qr_data": qr_data}), 200
    except Error as e:
        logger.error(f"Database error during borrow request: {e}")
        return jsonify({"status": "error", "message": f"Database error: {e}"}), 500
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/api/borrow/confirm', methods=['POST'])
@jwt_required()
def confirm_borrow():
    identity = get_jwt_identity()
    claims = get_jwt()
    if claims['user_type'] != 'admin':
        logger.warning(f"Borrow confirm failed: Admin access required for user {identity}")
        return jsonify({"status": "error", "message": "Admin access required"}), 403

    try:
        data = request.get_json()
        user_id = data.get('user_id')
        book_id = data.get('book_id')
        action = data.get('action')

        if not all([user_id, book_id, action]) or action != 'borrow':
            logger.warning("Borrow confirm failed: Invalid request data")
            return jsonify({"status": "error", "message": "Invalid request data"}), 400

        try:
            user_id = int(user_id)
        except ValueError:
            logger.warning(f"Borrow confirm failed: Invalid user_id format: {user_id}")
            return jsonify({"status": "error", "message": "Invalid user_id format"}), 400

        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor(dictionary=True)

        # Fetch book and validate availability with a lock to prevent race conditions
        cursor.execute("SELECT * FROM books WHERE book_id = %s AND available_copies > 0 FOR UPDATE", (book_id,))
        book = cursor.fetchone()
        if not book:
            logger.warning(f"Borrow confirm failed: Book {book_id} not available")
            return jsonify({"status": "error", "message": "Book not available"}), 404

        cursor.execute("SELECT * FROM users WHERE user_id = %s", (user_id,))
        user = cursor.fetchone()
        if not user:
            logger.warning(f"Borrow confirm failed: User {user_id} not found")
            return jsonify({"status": "error", "message": "User not found"}), 404

        borrow_date = datetime.now()
        due_date = borrow_date + timedelta(days=BORROW_PERIOD_DAYS)

        cursor.execute(
            "UPDATE books SET available_copies = available_copies - 1 WHERE book_id = %s",
            (book_id,)
        )
        cursor.execute(
            "INSERT INTO borrow_transactions (user_id, book_id, borrow_date, due_date, status) VALUES (%s, %s, %s, %s, %s)",
            (user_id, book_id, borrow_date, due_date, 'borrowed')
        )
        connection.commit()
        logger.info(f"Borrow confirmed: User {user_id}, Book {book_id}, Due Date: {due_date}")
        return jsonify({"status": "success", "message": "Borrow confirmed"}), 200
    except Error as e:
        logger.error(f"Database error confirming borrow: {e}")
        return jsonify({"status": "error", "message": f"Database error: {e}"}), 500
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/api/return/request', methods=['POST'])
@jwt_required()
def request_return():
    identity = get_jwt_identity()
    claims = get_jwt()
    if claims['user_type'] != 'reader':
        logger.warning(f"Return request failed: Reader access required for user {identity}")
        return jsonify({"status": "error", "message": "Reader access required"}), 403

    try:
        data = request.get_json()
        book_id = data.get('book_id')

        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor(dictionary=True)

        # Check if the user has an active borrow transaction for this book
        cursor.execute(
            "SELECT * FROM borrow_transactions WHERE user_id = %s AND book_id = %s AND status = 'borrowed'",
            (identity, book_id)
        )
        transaction = cursor.fetchone()
        if not transaction:
            logger.warning(f"Return request failed: No active borrow transaction for user {identity}, book {book_id}")
            return jsonify({"status": "error", "message": "No active borrow transaction found"}), 404

        # Verify the book exists
        cursor.execute("SELECT * FROM books WHERE book_id = %s", (book_id,))
        book = cursor.fetchone()
        if not book:
            logger.warning(f"Return request failed: Book {book_id} not found")
            return jsonify({"status": "error", "message": "Book not found"}), 404

        qr_data = {
            "user_id": identity,
            "book_id": book_id,
            "action": "return"
        }
        logger.info(f"Return request generated for user {identity}, book {book_id}")
        return jsonify({"status": "success", "qr_data": qr_data}), 200
    except Error as e:
        logger.error(f"Database error during return request: {e}")
        return jsonify({"status": "error", "message": f"Database error: {e}"}), 500
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/api/return/confirm', methods=['POST'])
@jwt_required()
def confirm_return():
    identity = get_jwt_identity()
    claims = get_jwt()
    if claims['user_type'] != 'admin':
        logger.warning(f"Return confirm failed: Admin access required for user {identity}")
        return jsonify({"status": "error", "message": "Admin access required"}), 403

    try:
        data = request.get_json()
        user_id = data.get('user_id')
        book_id = data.get('book_id')
        action = data.get('action')

        if not all([user_id, book_id, action]) or action != 'return':
            logger.warning("Return confirm failed: Invalid request data")
            return jsonify({"status": "error", "message": "Invalid request data"}), 400

        try:
            user_id = int(user_id)
        except ValueError:
            logger.warning(f"Return confirm failed: Invalid user_id format: {user_id}")
            return jsonify({"status": "error", "message": "Invalid user_id format"}), 400

        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            "SELECT * FROM borrow_transactions WHERE user_id = %s AND book_id = %s AND status = 'borrowed'",
            (user_id, book_id)
        )
        transaction = cursor.fetchone()
        if not transaction:
            logger.warning(f"Return confirm failed: No active borrow transaction for user {user_id}, book {book_id}")
            return jsonify({"status": "error", "message": "No active borrow transaction found"}), 404

        cursor.execute("SELECT * FROM books WHERE book_id = %s", (book_id,))
        book = cursor.fetchone()
        if not book:
            logger.warning(f"Return confirm failed: Book {book_id} not found")
            return jsonify({"status": "error", "message": "Book not found"}), 404

        return_date = datetime.now()
        fine = calculate_fine(transaction['borrow_date'], transaction['due_date'], return_date, 'returned', transaction['fine_paid'])

        cursor.execute(
            "UPDATE books SET available_copies = available_copies + 1 WHERE book_id = %s",
            (book_id,)
        )
        cursor.execute(
            "UPDATE borrow_transactions SET status = 'returned', return_date = %s, fine = %s WHERE id = %s",
            (return_date, fine, transaction['id'])
        )
        connection.commit()
        logger.info(f"Return confirmed: User {user_id}, Book {book_id}, Fine: ${fine}")
        return jsonify({"status": "success", "message": "Return confirmed", "fine": fine}), 200
    except Error as e:
        logger.error(f"Database error confirming return: {e}")
        return jsonify({"status": "error", "message": f"Database error: {e}"}), 500
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/api/transactions', methods=['GET'])
@jwt_required()
def get_transactions():
    identity = get_jwt_identity()
    claims = get_jwt()
    if claims['user_type'] != 'admin':
        logger.warning(f"Fetch transactions failed: Admin access required for user {identity}")
        return jsonify({"status": "error", "message": "Admin access required"}), 403

    try:
        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor(dictionary=True)

        cursor.execute("SELECT * FROM borrow_transactions")
        transactions = cursor.fetchall()

        for transaction in transactions:
            fine = calculate_fine(
                transaction['borrow_date'],
                transaction['due_date'],
                transaction['return_date'],
                transaction['status'],
                transaction['fine_paid']
            )
            if fine != float(transaction['fine']):
                cursor.execute(
                    "UPDATE borrow_transactions SET fine = %s WHERE id = %s",
                    (fine, transaction['id'])
                )
            transaction['fine'] = fine
            transaction['fine_paid'] = bool(transaction['fine_paid'])
            transaction['payment_status'] = transaction['payment_status'] if transaction['payment_status'] else None

        connection.commit()
        logger.info(f"Fetched {len(transactions)} transactions for admin {identity}")
        return jsonify({"status": "success", "transactions": transactions}), 200
    except Error as e:
        logger.error(f"Database error fetching transactions: {e}")
        return jsonify({"status": "error", "message": f"Database error: {e}"}), 500
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/api/user/transactions', methods=['GET'])
@jwt_required()
def get_user_transactions():
    identity = get_jwt_identity()
    claims = get_jwt()
    if claims['user_type'] != 'reader':
        logger.warning(f"Fetch user transactions failed: Reader access required for user {identity}")
        return jsonify({"status": "error", "message": "Reader access required"}), 403

    try:
        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor(dictionary=True)

        cursor.execute("SELECT * FROM borrow_transactions WHERE user_id = %s", (identity,))
        transactions = cursor.fetchall()

        total_fine = 0.0
        for transaction in transactions:
            fine = calculate_fine(
                transaction['borrow_date'],
                transaction['due_date'],
                transaction['return_date'],
                transaction['status'],
                transaction['fine_paid']
            )
            if fine != float(transaction['fine']):
                cursor.execute(
                    "UPDATE borrow_transactions SET fine = %s WHERE id = %s",
                    (fine, transaction['id'])
                )
            transaction['fine'] = fine
            if not transaction['fine_paid'] and transaction['payment_status'] != 'pending':
                total_fine += fine
            transaction['fine_paid'] = bool(transaction['fine_paid'])
            transaction['payment_status'] = transaction['payment_status'] if transaction['payment_status'] else None

        connection.commit()
        logger.info(f"Fetched {len(transactions)} transactions for user {identity}, Total Fine: ${total_fine}")
        return jsonify({"status": "success", "transactions": transactions, "total_fine": total_fine}), 200
    except Error as e:
        logger.error(f"Database error fetching user transactions: {e}")
        return jsonify({"status": "error", "message": f"Database error: {e}"}), 500
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/api/request-fine-payment', methods=['POST'])
@jwt_required()
def request_fine_payment():
    identity = get_jwt_identity()
    claims = get_jwt()
    if claims['user_type'] != 'reader':
        logger.warning(f"Request fine payment failed: Reader access required for user {identity}")
        return jsonify({"status": "error", "message": "Reader access required"}), 403

    try:
        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            "SELECT * FROM borrow_transactions WHERE user_id = %s AND fine > 0 AND fine_paid = FALSE AND (payment_status IS NULL OR payment_status != 'pending')",
            (identity,)
        )
        transactions = cursor.fetchall()

        if not transactions:
            logger.info(f"No unpaid fines to request payment for user {identity}")
            return jsonify({"status": "success", "message": "No unpaid fines to request payment for"}), 200

        total_fine = 0.0
        for transaction in transactions:
            fine = calculate_fine(
                transaction['borrow_date'],
                transaction['due_date'],
                transaction['return_date'],
                transaction['status'],
                transaction['fine_paid']
            )
            total_fine += fine

        if total_fine <= 0:
            logger.info(f"No unpaid fines after recalculation for user {identity}")
            return jsonify({"status": "success", "message": "No unpaid fines to request payment for"}), 200

        cursor.execute(
            "UPDATE borrow_transactions SET payment_status = 'pending' WHERE user_id = %s AND fine > 0 AND fine_paid = FALSE AND (payment_status IS NULL OR payment_status != 'pending')",
            (identity,)
        )
        connection.commit()

        logger.info(f"User {identity} requested fine payment: Total ${total_fine}")
        return jsonify({"status": "success", "message": f"Fine payment request for ${total_fine} submitted. Awaiting admin approval."}), 200
    except Error as e:
        logger.error(f"Database error during fine payment request: {e}")
        return jsonify({"status": "error", "message": f"Database error: {e}"}), 500
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/api/admin/pay-fine', methods=['POST'])
@jwt_required()
def admin_pay_fine():
    identity = get_jwt_identity()
    claims = get_jwt()
    if claims['user_type'] != 'admin':
        logger.warning(f"Admin pay fine failed: Admin access required for user {identity}")
        return jsonify({"status": "error", "message": "Admin access required"}), 403

    try:
        data = request.get_json()
        user_id = data.get('user_id')
        approve = data.get('approve', True)

        if not user_id:
            logger.warning("Admin pay fine failed: Missing user_id")
            return jsonify({"status": "error", "message": "Missing user_id"}), 400

        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor(dictionary=True)

        cursor.execute(
            "SELECT * FROM borrow_transactions WHERE user_id = %s AND fine > 0 AND fine_paid = FALSE AND payment_status = 'pending'",
            (user_id,)
        )
        transactions = cursor.fetchall()

        if not transactions:
            logger.warning(f"No pending fine payment requests for user {user_id}")
            return jsonify({"status": "error", "message": "No pending fine payment requests"}), 404

        total_fine = sum(transaction['fine'] for transaction in transactions)

        new_status = 'approved' if approve else 'rejected'
        if approve:
            cursor.execute(
                "UPDATE borrow_transactions SET fine_paid = TRUE, payment_status = %s WHERE user_id = %s AND fine > 0 AND fine_paid = FALSE AND payment_status = 'pending'",
                (new_status, user_id)
            )
        else:
            cursor.execute(
                "UPDATE borrow_transactions SET payment_status = %s WHERE user_id = %s AND fine > 0 AND fine_paid = FALSE AND payment_status = 'pending'",
                (new_status, user_id)
            )

        connection.commit()
        action = "approved" if approve else "rejected"
        logger.info(f"Admin {identity} {action} fine payment for user {user_id}: Total ${total_fine}")
        return jsonify({"status": "success", "message": f"Fine payment {action} for ${total_fine}"}), 200
    except Error as e:
        logger.error(f"Database error during admin fine payment: {e}")
        return jsonify({"status": "error", "message": f"Database error: {e}"}), 500
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)