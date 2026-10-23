# Kotton Kandy Beauty Bar 💜

**A Database-Driven Beauty Salon Management and E-Commerce Mobile Application**

## 📌 Project Overview

Kotton Kandy Beauty Bar is a cross-platform mobile application designed to improve the management of beauty salon operations and enhance the customer experience. The system provides a centralized platform where customers can book appointments, browse beauty services and products, purchase items, manage their profiles and communicate with the salon owner.

The application also provides an administrative interface for managing appointments, customers, products, inventory, orders, rewards, transactions and customer enquiries.

The system is developed using **Flutter and Firebase**, with integrations for online payments and courier services.

## 🎯 Project Objectives

- Digitize appointment scheduling and customer management.
- Provide real-time appointment booking and scheduling.
- Enable customers to browse and purchase beauty products.
- Improve inventory and order management.
- Support secure online payment processing.
- Introduce customer loyalty rewards and referral functionality.
- Improve communication between customers and the salon owner.
- Provide delivery scheduling and shipment tracking.
- Centralize business operations through an administrative dashboard.

## ✨ Key Features

### Customer Application

- User registration, login and authentication.
- Customer profile management.
- Browse beauty services and product catalogues.
- Book, cancel and reschedule appointments.
- Purchase beauty products.
- Shopping cart and order management.
- Online payment integration.
- Delivery tracking.
- Customer support chatbot.
- In-app chat with the salon owner.
- Loyalty rewards and referral codes.
- Push notifications and email updates.
- Ratings and reviews.

### Administration and Staff

- Role-based access control.
- Dashboard for business operations.
- Appointment and schedule management.
- Customer management.
- Product catalogue management.
- Inventory management.
- Order processing and management.
- Transaction management.
- Loyalty programme management.
- Delivery scheduling.
- Customer chat management.

## 🛠️ Technology Stack

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform application development |
| Dart | Application programming language |
| Firebase Authentication | User authentication |
| Cloud Firestore | Database and real-time data synchronization |
| Firebase Storage | Product images and uploaded media |
| Firebase Cloud Functions | Backend business logic and API integrations |
| Firebase Cloud Messaging | Push notifications |
| PayFast | Online payment integration |
| The Courier Guy API | Shipment creation and delivery tracking |
| Git and GitHub | Version control and source code management |
| Android Studio | Development, debugging and Android builds |

## 🏗️ System Architecture

The application follows a client–backend–external services architecture.

1. **Presentation layer:** Flutter mobile application for customers and Flutter Web administration interface.
2. **Backend layer:** Firebase Authentication, Cloud Firestore, Firebase Storage and Cloud Functions.
3. **Integration layer:** PayFast for payments, The Courier Guy for deliveries and an email service for transactional communications.

### Communication Flow

1. Users interact with the Flutter application.
2. Authentication and authorization determine which resources users may access.
3. The application reads and updates permitted data in Cloud Firestore.
4. Cloud Functions execute sensitive business operations and communicate with external services.
5. Payment and shipment results are verified and stored.
6. Firestore updates and push notifications communicate relevant changes to users.

## 📂 Project Structure

The project follows a Flutter application structure. The exact folders may vary depending on the current implementation.

```text
kottonkandy/
├── android/
├── ios/
├── web/
├── assets/
│   └── images/
├── lib/
│   ├── main.dart
│   ├── models/
│   ├── screens/
│   ├── widgets/
│   ├── services/
│   └── client_chat_system.dart
├── functions/
│   └── index.js
├── test/
├── pubspec.yaml
├── firebase.json
├── .gitignore
└── README.md
```

**Note:** The `functions/` directory is applicable if the Firebase Cloud Functions code is maintained in the same repository. Adapt the structure to match your actual project.

## ⚙️ Installation and Setup

### Prerequisites

Install the following tools before running the project:

- Flutter SDK
- Dart SDK (included with Flutter)
- Android Studio
- Visual Studio Code (optional)
- Git
- A Firebase project

### Step 1: Clone the repository

Replace the placeholder with your GitHub repository URL.

```bash
git clone github.com/RST-Sathiga/kottonkandybeautybarhttps://github.com/RST-Sathiga/kottonkandybeautybarhttps://github.com/RST-Sathiga/kottonkandybeautybar
cd kottonkandy
```

### Step 2: Install dependencies

```bash
flutter pub get
```

### Step 3: Configure Firebase

1. Create or select a project in the Firebase Console.
2. Register the required Android, iOS and web applications.
3. Configure Firebase for Flutter using FlutterFire CLI.
4. Generate or update the Firebase configuration.

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Ensure the generated Firebase configuration matches the platforms you intend to run.

### Step 4: Configure Firebase services

Enable and configure the services required by the application:

- Firebase Authentication.
- Cloud Firestore.
- Firebase Storage.
- Firebase Cloud Messaging.
- Cloud Functions, where applicable.

Configure Firestore Security Rules, Storage Rules and role-based permissions before using real customer data.

### Step 5: Run the application

Check connected devices:

```bash
flutter devices
```

Run the application:

```bash
flutter run
```

To run the web application, if web support is configured:

```bash
flutter run -d chrome
```

## 🔐 Security Considerations

Security is an important part of the application design.

- Enforce access control using Firebase Authentication and Security Rules.
- Restrict administrative operations to authorized users.
- Validate sensitive operations on the backend.
- Keep private API credentials and payment secrets out of source control.
- Verify payment notifications on the server before marking orders as paid.
- Protect customer information and uploaded files.
- Use idempotent backend operations to reduce duplicate payments, orders and reward allocations.

**Important:** Firebase client configuration is not a substitute for database security rules. Never commit service account private keys, secret API credentials or production payment secrets to GitHub.

## 🧪 Testing

Run the Flutter test suite with:

```bash
flutter test
```

Check the project for static analysis issues:

```bash
flutter analyze
```

Testing should cover authentication, appointment booking, order processing, role-based access, payment verification and database operations.

## 🚀 Future Enhancements

Potential future improvements include:

- Advanced appointment availability and staff scheduling.
- Automated appointment reminders.
- Improved sales and inventory reports.
- Customer feedback analytics.
- Enhanced loyalty programme features.
- Automated email notifications.
- More comprehensive integration and security testing.

## 🎓 Project Purpose

This project demonstrates the practical application of software engineering principles, mobile application development, database management, cloud computing, API integration and user-centred system design.

It is intended to provide a digital solution for the operational needs of Kotton Kandy Beauty Bar while improving convenience for customers and efficiency for the business.

## 👩‍💻 Developers

**Developers:** Tina Sathiga, Blessing Muzamani, Akani Nkiwinika, Zwavhudi Nevhutalu

**Project:** Kotton Kandy Beauty Bar Management System

**Technologies:** Flutter, Dart, Firebase and API Integration

## 📄 License

This project is developed for academic and demonstration purposes. Licensing and permission for commercial use should be defined by the project owner.
