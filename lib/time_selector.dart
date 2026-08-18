import 'package:flutter/material.dart';

class TimeSelector extends StatelessWidget {
  final String? selectedTime;

  final ValueChanged<String> onTimeSelected;

  final Set<String> bookedTimes;

  const TimeSelector({
    super.key,
    required this.selectedTime,
    required this.onTimeSelected,
    this.bookedTimes = const {},
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
    const Color pink = Color(0xFFE91E63);

    return Wrap(
      spacing: 10,
      runSpacing: 10,

      children: times.map(
            (time) {
          final bool isBooked =
          bookedTimes.contains(time);

          final bool isSelected =
              selectedTime == time;

          return ChoiceChip(
            label: Text(
              isBooked
                  ? '$time\nBooked'
                  : time,
              textAlign: TextAlign.center,
            ),

            selected: isSelected,

            onSelected: isBooked
                ? null
                : (_) {
              onTimeSelected(time);
            },

            selectedColor: pink,

            labelStyle: TextStyle(
              color: isSelected
                  ? Colors.white
                  : isBooked
                  ? Colors.grey
                  : Colors.black,
              fontWeight: FontWeight.w600,
            ),

            backgroundColor: isBooked
                ? Colors.grey.shade200
                : Colors.white,

            disabledColor:
            Colors.grey.shade200,

            side: BorderSide(
              color: isBooked
                  ? Colors.grey.shade300
                  : Colors.grey.shade300,
            ),

            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          );
        },
      ).toList(),
    );
  }
}