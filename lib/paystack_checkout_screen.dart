import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaystackCheckoutScreen extends StatefulWidget {
  final String authorizationUrl;
  final String reference;

  const PaystackCheckoutScreen({
    super.key,
    required this.authorizationUrl,
    required this.reference,
  });

  @override
  State<PaystackCheckoutScreen> createState() => _PaystackCheckoutScreenState();
}

class _PaystackCheckoutScreenState extends State<PaystackCheckoutScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;


  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (_finished) return;
            if (mounted) setState(() => _isLoading = true);
            _checkUrl(url);
          },
          onPageFinished: (String url) async {
            if (_finished) return;
            if (mounted) setState(() => _isLoading = false);
            _checkUrl(url);
            if (_finished) return;

            // Auto-complete if the page displays successful text
            try {
              final result = await _controller.runJavaScriptReturningResult('document.body.innerText');
              final content = result.toString();
              if (content.contains('Payment Successful')) {
                _finishPayment();
              }
            } catch (_) {
              // ignore: the page may not allow reading its text
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (!_finished) _checkUrl(request.url);
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  void _checkUrl(String url) {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('trxref=') ||
        lowerUrl.contains('reference=') ||
        lowerUrl.contains('checkout/close') ||
        lowerUrl.contains('standard/close') ||
        lowerUrl.contains('callback')) {
      _finishPayment();
    }
  }

  void _finishPayment() {
    if (_finished || !mounted) return;
    _finished = true;
    // Returns true to the calling screen so it can VERIFY the payment
    // with Paystack and then save the booking / order.
    Navigator.of(context).pop(true);
  }

  void _cancel() {
    if (_finished || !mounted) return;
    _finished = true;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paystack Payment'),
        backgroundColor: const Color(0xFF6B3A82),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cancel,
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF6B3A82)),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: ElevatedButton(
            onPressed: _finishPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B3A82),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Done / View Activities',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}