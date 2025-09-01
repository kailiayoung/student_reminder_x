import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:students_reminder/src/services/note_service.dart';
import 'package:students_reminder/src/services/user_service.dart';

class StudentProfilePage extends StatelessWidget {
  final String uid;
  const StudentProfilePage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Student Profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: UserService.instance.getUser(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          final data = snap.data?.data();
          if (data == null) return Center(child: Text('No data found'));
          final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
              .trim();
          final group = (data['courseGroup'] ?? '').toString() == 'mobile'
              ? 'Mobile App Development'
              : 'Web App Development';
          final bio = (data['bio'] ?? '') as String? ?? '';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text(group),
                leading: data['photoUrl'] != null
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(data['photoUrl']),
                      )
                    : CircleAvatar(child: Icon(Icons.person)),
              ),
              if (bio.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(bio),
                ),

              // TODO: Add Notes section
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Public Notes',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: NotesService.instance.watchPublicNotes(uid),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (snap.hasError) {
                      return Center(
                        child: Text('Error loading notes: ${snap.error}'),
                      );
                    }

                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(child: Text('No public notes'));
                    }

                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => Divider(height: 2),
                      itemBuilder: (context, i) {
                        final data = docs[i].data();
                        return ListTile(
                          title: Text(data['title'] ?? ''),
                          subtitle: Text(
                            data['body'] ?? '',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
