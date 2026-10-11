import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'paystack_checkout_screen.dart';

/// DEMO ONLY. Nothing here charges real money and card details are never
/// stored or sent anywhere. Remove the call to this helper before going live
/// (see the bottom of this file).
///
/// Shows the card / EFT screen first; if it "succeeds" the real Paystack page
/// opens next. Returns what PaystackCheckoutScreen returns (true = paid), or
/// false/null when the customer cancels or the simulated payment fails.
Future<bool?> payWithSimulatedStepThenPaystack(
  BuildContext context, {
  required int amountInCents,
  required String authorizationUrl,
  required String reference,
}) async {
  final bool? ok = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => SimulatedPaymentScreen(amountInCents: amountInCents),
    ),
  );
  if (ok != true || !context.mounted) return false;

  return Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => PaystackCheckoutScreen(
        authorizationUrl: authorizationUrl,
        reference: reference,
      ),
    ),
  );
}

class SimulatedPaymentScreen extends StatefulWidget {
  final int amountInCents;
  const SimulatedPaymentScreen({super.key, required this.amountInCents});

  @override
  State<SimulatedPaymentScreen> createState() => _SimulatedPaymentScreenState();
}

class _SimulatedPaymentScreenState extends State<SimulatedPaymentScreen> {
  static const Color primaryPurple = Color(0xFF6B3A82);

  // ---- Test cards (digits only) ------------------------------------------
  static const Map<String, String> _successCards = {
    '4084084084084081': 'Owner test card',
    '5531886652142950': 'Client test card',
  };
  static const String _declinedCard = '4000000000000002';
  static const String _noFundsCard = '5105105105105100';

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();

  bool _eft = false;
  String _bank = 'FNB';
  bool _processing = false;
  String? _error;

  static const _banks = ['FNB', 'Standard Bank', 'Absa', 'Nedbank', 'Capitec'];

  String get _amountText => 'R${(widget.amountInCents / 100).toStringAsFixed(2)}';

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  bool _expiryInFuture(String v) {
    final m = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(v);
    if (m == null) return false;
    final month = int.parse(m.group(1)!);
    final year = 2000 + int.parse(m.group(2)!);
    if (month < 1 || month > 12) return false;
    final now = DateTime.now();
    return year > now.year || (year == now.year && month >= now.month);
  }

  Future<void> _payCard() async {
    if (!_formKey.currentState!.validate()) return;
    final digits = _number.text.replaceAll(' ', '');

    setState(() {
      _processing = true;
      _error = null;
    });
    await Future.delayed(const Duration(seconds: 2)); // pretend to talk to bank
    if (!mounted) return;

    if (_successCards.containsKey(digits)) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _processing = false;
      if (digits == _noFundsCard) {
        _error = 'Payment declined: insufficient funds.';
      } else if (digits == _declinedCard) {
        _error = 'Payment declined by your bank.';
      } else {
        _error = 'This is not a valid test card. Tap "Test cards" below to see the ones that work.';
      }
    });
  }

  Future<void> _payEft() async {
    setState(() {
      _processing = true;
      _error = null;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Payment'),
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _processing ? null : () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'TEST MODE: no real money is charged and no card details are saved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
              Text('Amount to pay',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600)),
              Text(_amountText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold, color: primaryPurple)),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Card'), icon: Icon(Icons.credit_card)),
                  ButtonSegment(value: true, label: Text('EFT'), icon: Icon(Icons.account_balance)),
                ],
                selected: {_eft},
                onSelectionChanged: _processing
                    ? null
                    : (s) => setState(() {
                          _eft = s.first;
                          _error = null;
                        }),
              ),
              const SizedBox(height: 16),
              if (_eft) _eftForm() else _cardForm(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _processing ? null : (_eft ? _payEft : _payCard),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _processing
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_eft ? 'Approve in my bank' : 'Pay $_amountText',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                title: const Text('Test cards', style: TextStyle(fontSize: 14)),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
                children: const [
                  _Hint('4084 0840 8408 4081', 'Success (owner)'),
                  _Hint('5531 8866 5214 2950', 'Success (client)'),
                  _Hint('4000 0000 0000 0002', 'Declined'),
                  _Hint('5105 1051 0510 5100', 'Insufficient funds'),
                  SizedBox(height: 4),
                  Text('Use any future expiry (e.g. 12/30) and any 3-digit CVV.',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  SizedBox(height: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: _dec('Name on card', Icons.person_outline),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the name on the card' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _number,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, _CardNumberFormatter()],
            decoration: _dec('Card number', Icons.credit_card),
            validator: (v) {
              final d = (v ?? '').replaceAll(' ', '');
              return d.length < 13 ? 'Enter a valid card number' : null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _expiry,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, _ExpiryFormatter()],
                  decoration: _dec('MM/YY', Icons.calendar_today_outlined),
                  validator: (v) => _expiryInFuture(v ?? '') ? null : 'Invalid expiry',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _cvv,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: _dec('CVV', Icons.lock_outline),
                  validator: (v) => (v ?? '').length < 3 ? 'Invalid CVV' : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _eftForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: _bank,
          decoration: _dec('Choose your bank', Icons.account_balance),
          items: _banks.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
          onChanged: _processing ? null : (v) => setState(() => _bank = v ?? _bank),
        ),
        const SizedBox(height: 8),
        Text(
          'You will "approve" this payment as if you were in your $_bank banking app.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
}

class _Hint extends StatelessWidget {
  final String number;
  final String label;
  const _Hint(this.number, this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(number, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    final d = next.text.replaceAll(' ', '');
    final capped = d.length > 19 ? d.substring(0, 19) : d;
    final b = StringBuffer();
    for (int i = 0; i < capped.length; i++) {
      if (i > 0 && i % 4 == 0) b.write(' ');
      b.write(capped[i]);
    }
    final s = b.toString();
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    var d = next.text.replaceAll('/', '');
    if (d.length > 4) d = d.substring(0, 4);
    final s = d.length > 2 ? '${d.substring(0, 2)}/${d.substring(2)}' : d;
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}
