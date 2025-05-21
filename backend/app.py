from flask import Flask, request, jsonify
from flask_jwt_extended import JWTManager, jwt_required, create_access_token, get_jwt_identity, get_jwt
from flask_cors import CORS
import mysql.connector
from mysql.connector import Error
import bcrypt
from datetime import datetime
import logging

app = Flask(__name__)
app.config['JWT_SECRET_KEY'] = '0afce35125fb4100282bae99fcd6c8eb'
jwt = JWTManager(app)

# Enable CORS for all routes, allowing requests from the Flutter app
CORS(app, resources={r"/api/*": {"origins": "*"}})

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

db_config = {
    'host': 'localhost',
    'user': 'root',
    'password': 'Jaiho@123',
    'database': 'campuslib'
}

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
            # Convert user_id to string for JWT subject
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

        cursor.execute("SELECT * FROM books WHERE book_id = %s AND available_copies > 0", (book_id,))
        book = cursor.fetchone()
        if not book:
            logger.warning(f"Borrow confirm failed: Book {book_id} not available")
            return jsonify({"status": "error", "message": "Book not available"}), 404

        cursor.execute("SELECT * FROM users WHERE user_id = %s", (user_id,))
        user = cursor.fetchone()
        if not user:
            logger.warning(f"Borrow confirm failed: User {user_id} not found")
            return jsonify({"status": "error", "message": "User not found"}), 404

        cursor.execute(
            "UPDATE books SET available_copies = available_copies - 1 WHERE book_id = %s",
            (book_id,)
        )
        cursor.execute(
            "INSERT INTO borrow_transactions (user_id, book_id, borrow_date, status) VALUES (%s, %s, %s, %s)",
            (user_id, book_id, datetime.now(), 'borrowed')
        )
        connection.commit()
        logger.info(f"Borrow confirmed: User {user_id}, Book {book_id}")
        return jsonify({"status": "success", "message": "Borrow confirmed"}), 200
    except Error as e:
        logger.error(f"Database error confirming borrow: {e}")
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

        cursor.execute(
            "UPDATE books SET available_copies = available_copies + 1 WHERE book_id = %s",
            (book_id,)
        )
        cursor.execute(
            "UPDATE borrow_transactions SET status = 'returned', return_date = %s WHERE id = %s",
            (datetime.now(), transaction['id'])
        )
        connection.commit()
        logger.info(f"Return confirmed: User {user_id}, Book {book_id}")
        return jsonify({"status": "success", "message": "Return confirmed"}), 200
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
        logger.info(f"Fetched {len(transactions)} transactions for user {identity}")
        return jsonify({"status": "success", "transactions": transactions}), 200
    except Error as e:
        logger.error(f"Database error fetching user transactions: {e}")
        return jsonify({"status": "error", "message": f"Database error: {e}"}), 500
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)