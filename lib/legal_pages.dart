import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const Color primaryPurple = Color(0xFF6B3A82);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Privacy Policy"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text(
            "Privacy & Data Protection Policy",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryPurple),
          ),
          SizedBox(height: 12),
          Text(
            "1. Information Collection\n"
                "We collect personal information necessary for providing beauty treatments and managing bookings. This includes your full name, email address, phone number, profile pictures, booking history, and device preferences.\n\n"
                "2. Health & Treatment Information\n"
                "Certain specialized services (e.g., facials, chemical peels, lash extensions) may require disclosure of skin allergies, medical conditions, or sensitivity history to ensure treatment safety. This data is kept strictly confidential and is accessible only by authorized salon staff.\n\n"
                "3. Analytics & Preference Tracking\n"
                "We store local app settings (such as dark mode preferences and notification settings) on your device via local storage, and synced app data using secure Firebase Cloud services.\n\n"
                "4. Third-Party Sharing\n"
                "Kotton Kandy does not sell, rent, or trade your personal data to third parties. Data is shared exclusively with integrated service providers (such as payment processors and authentication services) solely to perform app features.\n\n"
                "5. Data Retention & Account Deletion\n"
                "Your profile data and appointment history are stored as long as your account remains active. You may permanently delete your account and clear all stored data at any time through the Account Management menu in Settings.",
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  static const Color primaryPurple = Color(0xFF6B3A82);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Terms of Service"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text(
            "Terms & Salon Policies",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryPurple),
          ),
          SizedBox(height: 12),
          Text(
            "1. Booking & Arrival\n"
                "Please arrive at least 10 minutes prior to your scheduled appointment. Arriving late by 15 minutes or more may result in a shortened treatment duration or cancellation to avoid delaying subsequent client appointments.\n\n"
                "2. Cancellation & Rescheduling\n"
                "We require at least 24 hours' notice for cancellations or rescheduling. Repeated last-minute cancellations or no-shows may lead to temporary suspension of online booking privileges or require advance deposit requirements for future slots.\n\n"
                "3. Refunds & Service Satisfaction\n"
                "Due to the nature of beauty services, completed procedures are non-refundable. If you are dissatisfied with a service (e.g., nail lifting or lash retention issues), please notify us within 48 hours of your appointment for an assessment and complimentary touch-up if applicable.\n\n"
                "4. Patch Tests & Health Safety\n"
                "First-time clients receiving specialized treatments like lash extensions or chemical brow tinting may be required to complete a patch test prior to application. Kotton Kandy reserves the right to decline service if a client presents visible skin infections, open wounds, or communicable conditions.\n\n"
                "5. Pricing & Payments\n"
                "All pricing displayed in the app is in South African Rands (R) and includes applicable service charges. Prices are subject to change, but confirmed appointments will always honor the rate quoted at booking.\n\n"
                "6. Conduct & Account Security\n"
                "Users must maintain respectful communication with beauty professionals via the app chat system. Accounts engaging in fraudulent bookings, harassment, or abuse will be terminated immediately.",
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}