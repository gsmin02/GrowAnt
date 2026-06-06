import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/mock/mock_data.dart';

class ExchangeScreen extends StatefulWidget {
  const ExchangeScreen({super.key});

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  bool _krwToUsd = true; // true: KRW→USD, false: USD→KRW
  final _controller = TextEditingController();
  double _result = 0;

  void _calculate(String value) {
    final input = double.tryParse(value.replaceAll(',', '')) ?? 0;
    setState(() {
      _result = _krwToUsd ? input / mockExchangeRate : input * mockExchangeRate;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final fmtD = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(title: const Text('환전')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _BalanceChip(
                        label: '보유 KRW',
                        value: '${fmt.format(mockKrwBalance)}원',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BalanceChip(
                        label: '보유 USD',
                        value: '\$${fmtD.format(mockUsdBalance)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '환율: 1 USD = ${fmt.format(mockExchangeRate.round())}원',
                  style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DirectionToggle(
            krwToUsd: _krwToUsd,
            onToggle: () {
              setState(() {
                _krwToUsd = !_krwToUsd;
                _controller.clear();
                _result = 0;
              });
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _krwToUsd ? '환전할 KRW' : '환전할 USD',
                  style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  onChanged: _calculate,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: _krwToUsd ? '원 입력' : 'USD 입력',
                    suffix: Text(
                      _krwToUsd ? 'KRW' : 'USD',
                      style: const TextStyle(color: Color(0xFF888888)),
                    ),
                    border: InputBorder.none,
                  ),
                ),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  _krwToUsd ? '받을 USD' : '받을 KRW',
                  style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _krwToUsd
                      ? '\$${fmtD.format(_result)}'
                      : '${fmt.format(_result.round())}원',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF111111),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _result > 0
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('환전 완료 (Mock)'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                : null,
            child: const Text('환전하기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _BalanceChip extends StatelessWidget {
  final String label;
  final String value;
  const _BalanceChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

class _DirectionToggle extends StatelessWidget {
  final bool krwToUsd;
  final VoidCallback onToggle;
  const _DirectionToggle({required this.krwToUsd, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(krwToUsd ? 'KRW' : 'USD',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onToggle,
          icon: const Icon(Icons.swap_horiz, size: 28),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF111111),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(8),
          ),
        ),
        const SizedBox(width: 8),
        Text(krwToUsd ? 'USD' : 'KRW',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }
}
