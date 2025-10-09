// main.dart
// Verzia 11.0: Prepojenie na produkčný online server.

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

// DÔLEŽITÉ: Pred spustením pridajte do projektu súbor firebase_options.dart
// vygenerovaný pomocou príkazu `flutterfire configure`
import 'firebase_options.dart';

// --- DÁTOVÉ MODELY ---
class FamilyMember {
  final String id;
  final String firstName;
  final String role;
  FamilyMember({required this.id, required this.firstName, required this.role});
}

class Subject {
  final String id;
  final String subjectName;
  Subject({required this.id, required this.subjectName});
}

class UploadedFile {
    final String id;
    final String fileName;
    UploadedFile({required this.id, required this.fileName});
}

class QuizQuestion {
    final String id;
    final String questionText;
    final Map<String, String> options;
    final String correctOption;
    QuizQuestion({required this.id, required this.questionText, required this.options, required this.correctOption});
    factory QuizQuestion.fromJson(Map<String, dynamic> json) {
        // Použijeme dočasné ID, ak z API nepríde
        return QuizQuestion(id: json['id'] ?? uuid.v4(), questionText: json['question_text'], options: Map<String, String>.from(json['options']), correctOption: json['correct_option']);
    }
}

class Quiz {
    final String id;
    final String topic;
    final List<QuizQuestion> questions;
    Quiz({required this.id, required this.topic, required this.questions});
    factory Quiz.fromJson(Map<String, dynamic> json) {
        var questionsList = json['questions'] as List;
        List<QuizQuestion> questions = questionsList.map((i) => QuizQuestion.fromJson(i)).toList();
        return Quiz(id: json['id'], topic: json['topic'], questions: questions);
    }
}

class Mission {
  final String title;
  final String description;
  final Map<String, dynamic> goals;
  final Map<String, dynamic> progress;
  Mission({required this.title, required this.description, required this.goals, required this.progress});

  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      title: json['title'] ?? 'Neznáma misia',
      description: json['description'] ?? '',
      goals: json['goals'] ?? {},
      progress: json['progress'] ?? {},
    );
  }
}

// --- HLAVNÁ FUNKCIA APLIKÁCIE ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ParentFyApp());
}

// --- ZÁKLADNÁ ŠTRUKTÚRA APLIKÁCIE ---
class ParentFyApp extends StatelessWidget {
  const ParentFyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parent Fy',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Inter'),
      home: const AuthWrapper(),
      routes: { '/register': (context) => const RegistrationScreen() },
    );
  }
}

// --- Wrapper na správu prihlásenia ---
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (snapshot.hasData) return const MainNavigator();
        return const LoginScreen();
      },
    );
  }
}

// --- NAVIGÁCIA ---
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});
  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}
class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0;
  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    FamilyManagementScreen(),
    MissionsScreen(),
  ];
  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Parent Fy"),
        actions: [ IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()) ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Prehľad'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Rodina'),
          BottomNavigationBarItem(icon: Icon(Icons.bullseye), label: 'Misie'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

// --- OBRAZOVKY ---

// 1. Prihlasovacia Obrazovka
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Chyba prihlásenia"), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _isLoading = false);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Vitajte v Parent Fy', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Heslo'), obscureText: true),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                      child: const Text('Prihlásiť sa'),
                    ),
              TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: const Text('Nemáte účet? Zaregistrujte sa'),
                )
            ],
          ),
        ),
      ),
    );
  }
}

// 2. Registračná obrazovka
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}
class _RegistrationScreenState extends State<RegistrationScreen> {
  final _familyNameController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  Future<void> _register() async {
    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      String? token = await userCredential.user?.getIdToken();
      if (token != null) {
        final success = await _apiService.createUserProfile(
            token,
            _familyNameController.text.trim(),
            _parentNameController.text.trim(),
        );
        if (!success && mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nepodarilo sa vytvoriť profil."), backgroundColor: Colors.red));
        }
      }
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Chyba registrácie"), backgroundColor: Colors.red));
    }
     if (mounted) setState(() => _isLoading = false);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vytvoriť nový účet')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(controller: _familyNameController, decoration: const InputDecoration(labelText: 'Názov rodiny (napr. Novákovci)')),
            TextField(controller: _parentNameController, decoration: const InputDecoration(labelText: 'Vaše krstné meno')),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Váš email'), keyboardType: TextInputType.emailAddress),
            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Heslo'), obscureText: true),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _register,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    child: const Text('Zaregistrovať sa'),
                  ),
          ],
        ),
      ),
    );
  }
}

// 3. Dashboard
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const Center(child: Text("Používateľ nie je prihlásený."));
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) return const Center(child: Text("Vytvára sa profil..."));
        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final familyId = userData['family_id'];
        if (familyId == null) return const Center(child: Text("Chýba priradenie k rodine."));
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('families').doc(familyId).snapshots(),
          builder: (context, familySnapshot) {
            if (!familySnapshot.hasData || !familySnapshot.data!.exists) return const Center(child: CircularProgressIndicator());
            final familyData = familySnapshot.data!.data() as Map<String, dynamic>;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Text(familyData['family_name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 20),
                   Text('XP body: ${familyData['xp_total']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// 4. Správa rodiny
class FamilyManagementScreen extends StatelessWidget {
  const FamilyManagementScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final apiService = ApiService();
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final familyId = snapshot.data!.get('family_id');
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').where('family_id', isEqualTo: familyId).snapshots(),
            builder: (context, streamSnapshot) {
              if (streamSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!streamSnapshot.hasData) return const Center(child: Text("Žiadni členovia rodiny."));
              final members = streamSnapshot.data!.docs.map((doc) => FamilyMember(id: doc.id, firstName: doc.get('first_name'), role: doc.get('role'))).toList();
              return ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: Icon(member.role == 'parent' ? Icons.person_rounded : Icons.child_care_rounded),
                      title: Text(member.firstName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(member.role),
                      onTap: member.role == 'child' ? () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChildDetailScreen(child: member))) : null,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddChildDialog(context, apiService), child: const Icon(Icons.add), tooltip: 'Pridať dieťa'),
    );
  }

  void _showAddChildDialog(BuildContext context, ApiService apiService) {
    final nameController = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(
        title: const Text('Pridať nové dieťa'),
        content: TextField(controller: nameController, decoration: const InputDecoration(hintText: "Meno dieťaťa")),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Zrušiť')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                 await apiService.addChild(nameController.text.trim());
                 Navigator.of(context).pop();
              }
            },
            child: const Text('Pridať'),
          ),
        ],
      ),
    );
  }
}

// 5. Detail dieťaťa
class ChildDetailScreen extends StatelessWidget {
  final FamilyMember child;
  const ChildDetailScreen({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    return Scaffold(
      appBar: AppBar(title: Text(child.firstName)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('subjects').where('child_id', isEqualTo: child.id).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final subjects = snapshot.data!.docs.map((doc) => Subject(id: doc.id, subjectName: doc.get('subject_name'))).toList();
          return ListView.builder(
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text(subject.subjectName),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectDetailScreen(child: child, subject: subject))),
                ),
              );
            },
          );
        },
      ),
       floatingActionButton: FloatingActionButton(onPressed: () => _showAddSubjectDialog(context, child.id, apiService), child: const Icon(Icons.add), tooltip: 'Pridať predmet'),
    );
  }

  void _showAddSubjectDialog(BuildContext context, String childId, ApiService apiService) {
     final nameController = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(
        title: const Text('Pridať nový predmet'),
        content: TextField(controller: nameController, decoration: const InputDecoration(hintText: "Názov predmetu")),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Zrušiť')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                 await apiService.addSubject(childId, nameController.text.trim());
                 Navigator.of(context).pop();
              }
            },
            child: const Text('Pridať'),
          ),
        ],
      ),
    );
  }
}

// 6. Detail predmetu
class SubjectDetailScreen extends StatelessWidget {
  final FamilyMember child;
  final Subject subject;
  const SubjectDetailScreen({super.key, required this.child, required this.subject});

  Future<void> _uploadFile(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;
        String userId = FirebaseAuth.instance.currentUser!.uid;
        try {
            final ref = FirebaseStorage.instance.ref('uploads/$userId/${subject.id}/$fileName');
            await ref.putFile(file);
            final url = await ref.getDownloadURL();
            await FirebaseFirestore.instance.collection('uploaded_files').add({
                'subject_id': subject.id,
                'file_name': fileName,
                'storage_url': url,
                'uploaded_at': FieldValue.serverTimestamp(),
            });
            if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Súbor úspešne nahraný!'), backgroundColor: Colors.green));
        } catch (e) {
            if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chyba pri nahrávaní.'), backgroundColor: Colors.red));
        }
    }
  }

  void _generateQuiz(BuildContext context) {
    final topicController = TextEditingController();
    final apiService = ApiService();
    showDialog(context: context, builder: (context) => AlertDialog(
        title: const Text('Vygenerovať kvíz'),
        content: TextField(controller: topicController, decoration: const InputDecoration(hintText: "Zadajte tému (napr. Zlomky)")),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Zrušiť')),
          ElevatedButton(
            onPressed: () async {
              if (topicController.text.isNotEmpty) {
                Navigator.of(context).pop();
                final quiz = await apiService.generateQuiz(child.id, subject.id, topicController.text.trim());
                if (quiz != null && context.mounted) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => QuizScreen(quiz: quiz)));
                }
              }
            },
            child: const Text('Generovať'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(subject.subjectName)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('uploaded_files').where('subject_id', isEqualTo: subject.id).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final files = snapshot.data!.docs.map((doc) => UploadedFile(id: doc.id, fileName: doc.get('file_name'))).toList();
          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
                final file = files[index];
                return ListTile(
                    leading: const Icon(Icons.insert_drive_file),
                    title: Text(file.fileName),
                );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(onPressed: () => _generateQuiz(context), label: const Text("Nový Kvíz"), icon: const Icon(Icons.quiz), heroTag: 'generateQuiz'),
          const SizedBox(height: 10),
          FloatingActionButton.extended(onPressed: () => _uploadFile(context), label: const Text("Nahrať Súbor"), icon: const Icon(Icons.upload_file), heroTag: 'uploadFile'),
        ],
      ),
    );
  }
}

// 7. Kvízová obrazovka
class QuizScreen extends StatefulWidget {
  final Quiz quiz;
  const QuizScreen({super.key, required this.quiz});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}
class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  bool _answered = false;
  final _apiService = ApiService();

  void _answerQuestion(String selectedOption) async {
    if (_answered) return;
    setState(() => _answered = true);
    
    final question = widget.quiz.questions[_currentQuestionIndex];
    bool isCorrect = question.correctOption == selectedOption;
    
    await _apiService.answerQuestion(widget.quiz.id, question.id, selectedOption);
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isCorrect ? 'Správne!' : 'Nesprávne. Správna odpoveď: ${question.correctOption}'),
      backgroundColor: isCorrect ? Colors.green : Colors.orange,
    ));

    await Future.delayed(const Duration(seconds: 2));
    if (_currentQuestionIndex < widget.quiz.questions.length - 1) {
      setState(() { _currentQuestionIndex++; _answered = false; });
    } else {
      if(mounted) _showResults();
    }
  }

  void _showResults() {
    showDialog(context: context, builder: (context) => AlertDialog(
        title: const Text('Kvíz dokončený!'),
        content: const Text('Skvelá práca!'),
        actions: [ ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')) ],
      )
    ).then((_) => Navigator.of(context).pop());
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.quiz.questions[_currentQuestionIndex];
    return Scaffold(
      appBar: AppBar(title: Text(widget.quiz.topic)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Otázka ${_currentQuestionIndex + 1}/${widget.quiz.questions.length}'),
            const SizedBox(height: 8),
            Text(question.questionText, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ...question.options.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: ElevatedButton(
                  onPressed: _answered ? null : () => _answerQuestion(entry.key),
                  child: Text('${entry.key}: ${entry.value}'),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

// 8. Obrazovka Misií
class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});
  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}
class _MissionsScreenState extends State<MissionsScreen> {
  final _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<Mission?>(
          future: _apiService.getCurrentMission(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) return const Center(child: Text("Žiadna aktívna misia."));
            final mission = snapshot.data!;
            final quizGoal = mission.goals['quiz_count'] ?? 0;
            final quizProgress = mission.progress['quiz_count'] ?? 0;
            final overallProgress = (quizGoal > 0) ? (quizProgress / quizGoal) : 0.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Aktuálna Misia", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Card(
                  color: Colors.purple.shade50, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.purple.shade200)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mission.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple.shade800)),
                        const SizedBox(height: 8),
                        Text(mission.description, style: TextStyle(color: Colors.purple.shade700)),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: overallProgress, minHeight: 10,
                            backgroundColor: Colors.purple.shade100,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade600),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text("Pokrok: ${ (overallProgress * 100).toStringAsFixed(0) }%", style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Divider(height: 32),
                        Text("Ciele:", style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("Dokončené kvízy z predmetu '${mission.goals['subject']}': $quizProgress z $quizGoal"),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});
  @override
  Widget build(BuildContext context) => Center(child: Text('Obsah pre: $title'));
}

// --- SLUŽBA PRE KOMUNIKÁCIU S BACKENDOM ---
class ApiService {
  final String _baseUrl = "https://parent-fy-api-709796458721.europe-west1.run.app";

  Future<bool> createUserProfile(String token, String familyName, String firstName) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/create_profile'),
        headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'family_name': familyName, 'first_name': firstName}),
      );
      return response.statusCode == 201;
    } catch (e) { print("Create profile error: $e"); return false; }
  }

  Future<void> addChild(String firstName) async {
    String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return;
    await http.post(
      Uri.parse('$_baseUrl/children'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'first_name': firstName}),
    );
  }

  Future<void> addSubject(String childId, String subjectName) async {
    String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return;
    await http.post(
      Uri.parse('$_baseUrl/children/$childId/subjects'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'subject_name': subjectName}),
    );
  }

  Future<Quiz?> generateQuiz(String childId, String subjectId, String topic) async {
    String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return null;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/quizzes/generate'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'child_id': childId, 'subject_id': subjectId, 'topic': topic}),
      );
      if (response.statusCode == 200) return Quiz.fromJson(jsonDecode(response.body));
      return null;
    } catch (e) { print("Generate quiz error: $e"); return null; }
  }

  Future<void> answerQuestion(String quizId, String questionId, String answer) async {
    String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return;
    try {
       await http.post(
        Uri.parse('$_baseUrl/questions/$questionId/answer?quiz_id=$quizId'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'answer': answer}),
      );
    } catch(e) { print("Answer question error: $e"); }
  }

  Future<Mission?> getCurrentMission() async {
    String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/missions/current'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.containsKey('title')) return Mission.fromJson(data);
      }
      return null;
    } catch (e) { print("Fetch mission error: $e"); return null; }
  }
}

// Dummy UUID class for models that need it if not provided by a package
class uuid {
  static String v4() => DateTime.now().millisecondsSinceEpoch.toString();
}

