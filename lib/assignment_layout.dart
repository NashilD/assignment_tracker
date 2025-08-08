import 'package:assignment_tracker/dates_status.dart';
import 'package:flutter/material.dart';

class AssignmentLayout extends StatefulWidget {
  const AssignmentLayout({super.key});

  @override
  AssignmentLayoutState createState() => AssignmentLayoutState();
}

class AssignmentLayoutState extends State<AssignmentLayout> {
  String? valueChoose;
  bool isEditing = false;

  // void _test() {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(
  //       content: Text("Hello"),
  //     ),
  //   );
  // }

  List<String> listItem = [
    "MOSI", "Statics", "Phylosifical Thinking", "Creative Thinking", "Accouting"
  ];

  @override
  Widget build(BuildContext context) {
    Color courseColor;
    if (valueChoose == "MOSI") {
      courseColor = Colors.pink;
    } else if (valueChoose == "Statics") {
      courseColor = Colors.purple;
    } else if (valueChoose == "Phylosifical Thinking") {
      courseColor = Colors.green;
    } else if (valueChoose == "Creative Thinking") {
      courseColor = Colors.orange;
    } else if (valueChoose == "Accouting") {
      courseColor = Colors.blue;
    } else {
      courseColor = Colors.green[600]!;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: courseColor,
          child: SizedBox(
            width: 130,
            height: 50,
            child: DropdownButton<String>(
              hint: const Center(
                child: Text(
                  "COURSE NAME",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
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
                  child: Center(
                    child: Text(valueItem),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Container(
          color: Colors.blue[200],
          padding: const EdgeInsets.all(25),
          child: Flexible(
            child: TextField(
              decoration: InputDecoration(
                hintText: "Eg: Read pages 227 - 307",
                labelText: "Assignment Description",
                labelStyle: const TextStyle(
                  fontSize: 20,
                  color: Colors.black,
                ),
                border: InputBorder.none,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      isEditing = !isEditing;
                    });
                  },
                  icon: Icon(
                   isEditing ? Icons.save : Icons.edit,
                  ),
                ),
              ),
            readOnly: !isEditing,
            maxLines: 5,
            ),
          ),
        ),
        const DatesStatus(),
      ],
    );
  }
}