import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';

class SurrealistFileDropTarget extends StatefulWidget {
  final ValueChanged<String> onFileSelected;
  final String label;

  const SurrealistFileDropTarget({
    super.key,
    required this.onFileSelected,
    required this.label,
  });

  @override
  _SurrealistFileDropTargetState createState() =>
      _SurrealistFileDropTargetState();
}

class _SurrealistFileDropTargetState extends State<SurrealistFileDropTarget> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (detail) async {
        setState(() {
          _dragging = false;
        });
        if (detail.files.isNotEmpty) {
          final filePath = detail.files.first.path;
          widget.onFileSelected(filePath);
        }
      },
      onDragEntered: (detail) {
        setState(() {
          _dragging = true;
        });
      },
      onDragExited: (detail) {
        setState(() {
          _dragging = false;
        });
      },
      child: GestureDetector(
        onTap: () async {
          var result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['epub'],
          );
          if (result != null && result.files.isNotEmpty) {
            final filePath = result.files.single.path;
            if (filePath != null) {
              widget.onFileSelected(filePath);
            }
          }
        },
        child: Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _dragging ? Colors.blue.withOpacity(0.4) : Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _dragging ? Colors.blueAccent : Colors.grey,
              width: 2,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_upload,
                  size: 50,
                  color: _dragging ? Colors.blueAccent : Colors.grey[600],
                ),
                Text(
                  _dragging ? 'Release to unleash the file!' : widget.label,
                  style: TextStyle(
                    color: _dragging ? Colors.blueAccent : Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
