import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DatesStatus extends StatefulWidget {
  const DatesStatus({super.key});

  @override
  State<DatesStatus> createState() => _DatesStatusState();
}

class _DatesStatusState extends State<DatesStatus> {
  String valueChoose = "Not Started";
  DateTime? dueDate;

  List<String> listItem = [
    "Not Started", "In Progress", "Done"
  ];
  
  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null && pickedDate != dueDate) {
      setState(() {
        dueDate = pickedDate;
      });
    }
  }

  int _calculateDaysRemaining() {
    if (dueDate == null) return -1;
    final currentDate = DateTime.now();
    final difference = dueDate!.difference(currentDate).inDays;
    return difference >= 0 ? difference + 1 : difference;
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    if (valueChoose == "Not Started") {
      statusColor = Colors.red;
    } else if (valueChoose == "In Progress") {
      statusColor = Colors.purple[300]!;
    } else {
      statusColor = Colors.green[900]!;
    }

    Color daysRemainingColor;
    if (dueDate == null) {
      daysRemainingColor = Colors.white;
    } else if (3 >= _calculateDaysRemaining()) {
      daysRemainingColor = Colors.red;
    } else if ((4 <= _calculateDaysRemaining()) && (14 > _calculateDaysRemaining())) {
      daysRemainingColor = Colors.orange[300]!;
    } else {
      daysRemainingColor = Colors.white;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            color: statusColor,
            child: SizedBox(
              width: 130,
              height: 30,
              child: DropdownButton<String>(
                hint: const Text(
                  "Not Started:",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                dropdownColor: Colors.white,
                icon: const Icon(Icons.arrow_drop_down),
                iconSize: 17,
                isExpanded: true,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                value: valueChoose,
                onChanged: (String? newValue) {
                  setState(() {
                    valueChoose = newValue ?? "Not Started";
                  });
                },
                items: listItem.map((String valueItem) {
                  return DropdownMenuItem<String>(
                    value: valueItem,
                    child: Text(valueItem),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        Flexible(
          child: Container(
            color: daysRemainingColor,
            child: SizedBox(
              width: 110,
              height: 30,
              child: Center(
                child: Text(
                  dueDate == null
                      ? 'Days Remaining: N/A'
                      : 'Days Remaining: ${_calculateDaysRemaining()}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
        Flexible(
          child: SizedBox(
            width: 200,
            height: 30,
            child: GestureDetector(
              onTap: () => _selectDueDate(context),
              child: Container(
                padding: const EdgeInsets.all(6.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                  borderRadius: BorderRadius.circular(5.0),
                ),
                child: Center(
                  child: Text(
                    dueDate == null
                        ? 'Select Due Date'
                        : 'Due: ${DateFormat.yMd().format(dueDate!)}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}