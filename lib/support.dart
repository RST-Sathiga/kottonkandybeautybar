import 'package:flutter/material.dart';

import 'client_chat_system.dart';
import 'report_issue.dart';

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
      "answer": "You earn 25 points for every order you place in the app, and 50 points for every completed booking (scan the QR code at the salon after your appointment). When you reach 500 points you can redeem them for R100 credit."
    },
    {
      "question": "How do I cancel or reschedule a booking?",
      "answer": "Open the Refunds page to cancel or reschedule a booking. Rescheduling costs an additional R100.00 each time, paid when you reschedule, and is non-refundable. If you cancel, you forfeit 50% of the total amount you paid and the other 50% is refunded. If the salon cancels your appointment, you receive a full refund."
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
      "answer": "If you cancel a booking yourself, you forfeit 50% of the total amount you paid and receive the other 50% back. Rescheduling costs an additional R100.00 each time, which is non-refundable. If the salon cancels your booking, you receive a full refund. Approved refunds are sent back to your original payment method within 3-5 business days."
    },
    {
      "question": "Do I have to pay to reschedule?",
      "answer": "Yes. Each time you reschedule, an additional fee of R100.00 is payable. The fee is non-refundable, and your original payment stays on the appointment. You are shown these rules and must agree to them before you pay for a booking."
    },
    {
      "question": "Why am I asked to send a photo of my face?",
      "answer": "For everyone's safety, the salon confirms who you are when you arrive. Before your appointment, open Profile > Appointment Verification and send a clear photo of your face. It is only used by the salon to verify you at your appointment."
    },
    {
      "question": "How do I contact customer support directly?",
      "answer": "You can chat with our assistant from this page or the Messages tab, and ask to speak to the owner at any time. You can also email support@kottonkandy.com."
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
        itemCount: _faqs.length + 2,
        itemBuilder: (context, index) {
          // First item: chat with the assistant
          if (index == 0) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryPurple,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent, color: Colors.white, size: 36),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need help?',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Chat with our assistant, or ask to speak to the owner.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryPurple,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatScreen(
                          salonId: 'kotton_kandy',
                          salonName: 'Kotton Kandy',
                        ),
                      ),
                    ),
                    child: const Text('Chat now'),
                  ),
                ],
              ),
            );
          }
          // Second item: report an issue
          if (index == 1) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                leading: const Icon(Icons.report_gmailerrorred_outlined,
                    color: primaryPurple, size: 30),
                title: const Text(
                  'Report an issue',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: const Text(
                    'Problem with a product, booking or delivery? Tell us and track the outcome.',
                    style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: primaryPurple),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportIssueScreen()),
                ),
              ),
            );
          }
          index = index - 2;
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