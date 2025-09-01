import 'package:flutter/material.dart';
import 'package:students_reminder/src/services/note_service.dart';
import 'package:students_reminder/src/shared/misc.dart';
import 'package:students_reminder/src/shared/validators_%20and_widgets.dart';
import 'package:students_reminder/src/shared/widgets/live_char_counter_text_field.dart';

class NoteEditorDialog extends StatefulWidget {
  final String uid;
  final String? noteId;
  final Map<String, dynamic>? existing;

  const NoteEditorDialog({
    super.key,
    required this.uid,
    this.noteId,
    this.existing,
  });

  @override
  State<NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<NoteEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final _globalKey = GlobalKey<FormState>();

  String _visibility = 'private';
  DateTime? _due;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?['title'] ?? '');
    _body = TextEditingController(text: widget.existing?['body'] ?? '');
    _visibility = widget.existing?['visibility'] ?? 'private';
    final dueTS = widget.existing?['dueDate'];
    if (dueTS != null) {
      _due = dueTS.toDate();
      _dueDateController.text = _due!.toString().split(' ').first;
    }
    _tags = List<String>.from(widget.existing?['tags'] ?? []);
  }

  String? _validateDueDate(String? value) {
    return dueDateValidator(_due);
  }

  void _addTag() {
    final tag = _tagController.text.trim().toLowerCase();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close),
              ),
              SizedBox(width: 8),
              Text(
                widget.noteId == null ? 'New Note' : 'Edit Note',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          Divider(height: 3, color: Colors.grey[300]),

          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _globalKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _title,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                        validator: validateNotEmpty,
                      ),
                      SizedBox(height: 16),
                      LiveCharCounterTextField(
                        controller: _body,
                        labelText: 'Body',
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        validator: validateNotEmpty,
                        maxLength: 150,
                      ),
                      SizedBox(height: 16),
                      // Tags Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tags',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          // Tag input
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _tagController,
                                  decoration: InputDecoration(
                                    hintText: 'Add a tag',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    suffixIcon: IconButton(
                                      onPressed: _addTag,
                                      icon: Icon(Icons.add),
                                    ),
                                  ),
                                  onFieldSubmitted: (_) => _addTag(),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          // Tag chips
                          if (_tags.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _tags
                                  .map(
                                    (tag) => Chip(
                                      label: Text(tag),
                                      deleteIcon: Icon(Icons.close, size: 18),
                                      onDeleted: () => _removeTag(tag),
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Visibility:'),
                                SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: _visibility,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'private',
                                      child: Text('Private'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'public',
                                      child: Text('Public'),
                                    ),
                                  ],
                                  onChanged: (v) => setState(
                                    () => _visibility = v ?? 'private',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Due Date:'),
                                SizedBox(height: 8),
                                TextFormField(
                                  controller: _dueDateController,
                                  decoration: InputDecoration(
                                    hintText: 'Select due date',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    suffixIcon: IconButton(
                                      onPressed: () async {
                                        final now = DateTime.now();
                                        final selDate = await showDatePicker(
                                          context: context,
                                          firstDate: now,
                                          lastDate: now.add(
                                            Duration(days: 365 * 5),
                                          ),
                                          initialDate: _due ?? now,
                                        );
                                        if (selDate != null) {
                                          setState(() {
                                            _due = selDate;
                                            _dueDateController.text = selDate
                                                .toString()
                                                .split(' ')
                                                .first;
                                          });
                                        }
                                      },
                                      icon: Icon(
                                        Icons.calendar_today,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  readOnly: true,
                                  validator: _validateDueDate,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 100), // Extra space for keyboard
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Pinned Save Button
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: ElevatedButton(
              onPressed: () async {
                if (_globalKey.currentState != null &&
                    !_globalKey.currentState!.validate()) {
                  return;
                }

                if (widget.noteId == null) {
                  await NotesService.instance.createNote(
                    widget.uid,
                    title: _title.text.trim(),
                    body: _body.text.trim(),
                    visibility: _visibility,
                    dueDate: _due,
                    tags: _tags,
                  );
                } else {
                  await NotesService.instance.updateNote(
                    widget.uid,
                    widget.noteId!,
                    title: _title.text.trim(),
                    body: _body.text.trim(),
                    visibility: _visibility,
                    dueDate: _due,
                    tags: _tags,
                  );
                }
                if (mounted) Navigator.pop(context, true);
                displaySnackBar(context, 'Note saved successfully');
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Save Note',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
