import 'package:cloud_functions/cloud_functions.dart';

class PaymentService {
  final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  // ============================================================
  // INITIALIZE PAYSTACK PAYMENT
  // ============================================================

  Future<PaymentInitialization> initializePayment({
    required String email,
    required int amountInKobo,
    required String bookingId,
    required String serviceName,
  }) async {
    try {
      final callable =
      _functions.httpsCallable(
        'initializePaystackPayment',
      );

      final result = await callable.call({
        'email': email,
        'amount': amountInKobo,
        'bookingId': bookingId,
        'serviceName': serviceName,
      });

      final data =
      Map<String, dynamic>.from(result.data);

      if (data['success'] != true) {
        throw Exception(
          data['message'] ??
              'Unable to initialize payment.',
        );
      }

      return PaymentInitialization(
        accessCode:
        data['accessCode'] as String,
        reference:
        data['reference'] as String,
      );
    } on FirebaseFunctionsException catch (e) {
      throw Exception(
        e.message ??
            'Payment service is unavailable.',
      );
    } catch (e) {
      throw Exception(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // VERIFY PAYSTACK PAYMENT
  // ============================================================

  Future<PaymentVerification> verifyPayment({
    required String reference,
  }) async {
    try {
      final callable =
      _functions.httpsCallable(
        'verifyPaystackPayment',
      );

      final result = await callable.call({
        'reference': reference,
      });

      final data =
      Map<String, dynamic>.from(result.data);

      return PaymentVerification(
        success: data['success'] == true,
        status:
        data['status']?.toString() ??
            'unknown',
        reference:
        data['reference']?.toString() ??
            reference,
      );
    } on FirebaseFunctionsException catch (e) {
      throw Exception(
        e.message ??
            'Unable to verify payment.',
      );
    } catch (e) {
      throw Exception(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }
}

// ============================================================
// PAYMENT INITIALIZATION MODEL
// ============================================================

class PaymentInitialization {
  final String accessCode;
  final String reference;

  const PaymentInitialization({
    required this.accessCode,
    required this.reference,
  });
}

// ============================================================
// PAYMENT VERIFICATION MODEL
// ============================================================

class PaymentVerification {
  final bool success;
  final String status;
  final String reference;

  const PaymentVerification({
    required this.success,
    required this.status,
    required this.reference,
  });
}