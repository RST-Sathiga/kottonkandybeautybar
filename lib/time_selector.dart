import 'package:flutter/material.dart';

class TimeSelector extends StatelessWidget {
  final String? selectedTime;
  final ValueChanged<String> onTimeSelected;

  const TimeSelector({
    super.key,
    required this.selectedTime,
    required this.onTimeSelected,
  });

  List<String> get times {
    return [
      '09:00',
      '10:00',
      '11:00',
      '12:00',
      '13:00',
      '14:00',
      '15:00',
      '16:00',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: times.map((time) {
        final bool isSelected = selectedTime == time;

        return ChoiceChip(
          label: Text(time),
          selected: isSelected,
          onSelected: (_) {
            onTimeSelected(time);
          },
        );
      }).toList(),
    );
  }
}