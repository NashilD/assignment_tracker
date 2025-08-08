import 'package:flutter/material.dart';
import 'assignment_layout.dart'; // Ensure the correct import path

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final List<GlobalKey<AssignmentLayoutState>> _keys = [];

  void _addAssignmentLayout() {
    setState(() {
      _keys.add(GlobalKey<AssignmentLayoutState>());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Assignment Tracker',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.purple[400],
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(6.0),
              itemCount: _keys.length,
              itemBuilder: (context, index) {
                return AssignmentLayout(key: _keys[index]);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAssignmentLayout,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}