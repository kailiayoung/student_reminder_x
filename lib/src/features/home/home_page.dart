import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:students_reminder/src/services/auth_service.dart';
import 'package:students_reminder/src/services/user_service.dart';
import 'package:students_reminder/src/widgets/group_filter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _group = 'mobile'; //default

  @override
  Widget build(BuildContext context) {
   
    final uid = AuthService.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: Text('Home')),
      body: Column(
        children: [
              GroupFilter(value: _group, onChanged: (val) => setState(() => _group = val)),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: UserService.instance.watchUserByCourseGroup(_group),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
               
                if(snap.hasError){
                  return Center(
                    child: Text('Error Detected: ${snap.error}'),
                  );
                }
                 final docs = snap.data?.docs ?? [];
                // if (docs.isEmpty) {
                //   return Center(
                //     child: Text('There are no students in this group'),
                //   );
                // }
                
                return ListView.separated(
                  separatorBuilder: (_, _) => Divider(height: 1),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i];
                    final isMe = data.id == uid;
                    final name =
                        '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
                            .trim();
                    final course = (data['courseGroup'] ?? '').toString();
                    return ListTile(
                      title: Text(name),
                      subtitle: Text(
                        course == 'mobile'
                            ? 'Mobile App Development'
                            : 'Web App Development',
                      ),
                      trailing: isMe
                          ? Text(
                              'Your Profile',
                              style: TextStyle(fontStyle: FontStyle.italic),
                            )
                          : null,
                      onTap: () {
                        //Open the Student Profile
                        Navigator.pushNamed(context, '/student/${data.id}');
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
