import 'package:flutter/material.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  // Brand Colors matching your screenshot
  static const Color cardBg = Color(0xFFFAF0F5); // Soft pink tile container
  static const Color primaryPurple = Color(0xFF6B3A82);

  // 10 FAQ Questions & Answers
  final List<Map<String, String>> _faqs = [
    {
      "question": "How do I earn loyalty points?",
      "answer": "You earn loyalty points automatically every time you complete a booking or make a purchase through the app. 100 points equals \$1 off your next order."
    },
    {
      "question": "How do I cancel or reschedule a booking?",
      "answer": "Go to the Bookings tab, select your active booking, and tap 'Cancel' or 'Reschedule'. Cancellations made 24 hours in advance receive a full refund."
    },
    {
      "question": "What payment options do you accept?",
      "answer": "We accept major credit/debit cards (Visa, Mastercard), mobile money, Apple Pay, and Google Pay."
    },
    {
      "question": "How do I update my personal details?",
      "answer": "Navigate to Profile > Personal Information, tap the Edit icon in the top right corner, update your details, and save your changes."
    },
    {
      "question": "Where can I track my orders?",
      "answer": "You can view real-time status updates for all physical purchases under Profile > My Orders."
    },
    {
      "question": "How do I apply a promo code?",
      "answer": "During checkout or booking payment, enter your code into the 'Promo Code' field and tap 'Apply' before confirming payment."
    },
    {
      "question": "What is the refund policy?",
      "answer": "Refunds are processed within 3-5 business days back to your original payment method upon approved cancellation or item return."
    },
    {
      "question": "How do I contact customer support directly?",
      "answer": "You can reach our live support team 24/7 via the Messages tab or by emailing support@kottonkandy.com."
    },
    {
      "question": "Is my payment information secure?",
      "answer": "Yes, all transactions are encrypted using industry-standard SSL encryption and processed through secure payment gateways."
    },
    {
      "question": "How do I reset my password?",
      "answer": "On the login screen, tap 'Forgot Password?'. Enter your registered email address to receive a password reset link."
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Help & Support",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _faqs.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                iconColor: primaryPurple,
                collapsedIconColor: primaryPurple,
                tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
                title: Text(
                  _faqs[index]["question"]!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
                children: [
                  Text(
                    _faqs[index]["answer"]!,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}