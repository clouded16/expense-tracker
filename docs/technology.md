# Technology Stack

This document explains the technologies used in the project
and the reason each technology was chosen.

## Flutter (Mobile Application)

Flutter is used to build the mobile application.

Why Flutter was chosen:
- Allows fast development of mobile user interfaces
- Uses a single codebase for the entire app
- Provides good support for Android features such as camera access
- Suitable for beginners while still being production-ready

Role in this project:
- Display screens and forms to the user
- Capture manual expense inputs
- Access device features like camera and SMS (with permission)
- Communicate with the backend server through APIs

Flutter does not perform expense analysis or decision-making.

---

## FastAPI (Backend Server)

FastAPI is used to build the backend server.

Why FastAPI was chosen:
- Simple and readable Python-based framework
- Automatically generates API documentation
- High performance and modern design
- Easy to maintain and extend

Role in this project:
- Receive data from the mobile application
- Validate and process expense information
- Store data in the database
- Perform spending analysis
- Generate explainable insights

FastAPI acts as the main logic and control center of the system.

---

## PostgreSQL (Database)

PostgreSQL is used as the database system.

Why PostgreSQL was chosen:
- Reliable and widely used in production systems
- Strong support for structured and time-based data
- Ensures data consistency and integrity
- Suitable for financial data storage

Role in this project:
- Store user accounts
- Store expense records
- Store generated insights
- Preserve historical data without silent deletion

The database serves as the long-term memory of the system.

---

## Artificial Intelligence (Optional)

Artificial intelligence is used in a limited and controlled manner.

Role of AI in this project:
- Assist in reading receipt text (OCR)
- Help interpret bank SMS formats
- Explain generated insights in natural language

AI is not used to:
- Make financial decisions
- Predict future spending
- Automatically modify user data

AI is designed to assist the user, not replace user judgment.
