import 'dart:convert';
import 'package:http/http.dart' as http;

class PaystackInitResult {
  final String authorizationUrl;
  final String accessCode;
  final String reference;

  PaystackInitResult({
    required this.authorizationUrl,
    required this.accessCode,
    required this.reference,
  });
}

class PaymentVerification {
  final bool success;
  final String status;
  final String reference;
  final String? message;

  PaymentVerification({
    required this.success,
    required this.status,
    required this.reference,
    this.message,
  });
}

class PaymentService {
  // Replace with your actual Paystack Test Secret Key (sk_test_...)
  static const String _secretKey = 'sk_test_e1d850daf881ea45ec7e9ee84577c7cffd672f16';

  Future<PaystackInitResult> initializePayment({
    required String email,
    required int amountInCents,
    required String bookingId,
    required String serviceName,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.paystack.co/transaction/initialize'),
      headers: {
        'Authorization': 'Bearer $_secretKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'amount': amountInCents,
        'currency': 'ZAR',
        'metadata': {
          'booking_id': bookingId,
          'service_name': serviceName,
        },
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['status'] == true) {
      return PaystackInitResult(
        authorizationUrl: data['data']['authorization_url'],
        accessCode: data['data']['access_code'],
        reference: data['data']['reference'],
      );
    } else {
      throw Exception(
        data['message'] ?? 'Failed to initialize Paystack payment.',
      );
    }
  }

  Future<PaymentVerification> verifyPayment({
    required String reference,
  }) async {
    final response = await http.get(
      Uri.parse('https://api.paystack.co/transaction/verify/$reference'),
      headers: {
        'Authorization': 'Bearer $_secretKey',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['status'] == true) {
      final status = data['data']['status'];
      return PaymentVerification(
        success: status == 'success',
        status: status,
        reference: reference,
      );
    } else {
      return PaymentVerification(
        success: false,
        status: 'failed',
        reference: reference,
      );
    }
  }
}