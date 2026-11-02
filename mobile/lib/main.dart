
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://tlttresnklfdgaanjgwv.supabase.co';
const supabaseKey = 'sb_publishable_54016q32muUvn9WcmfDkNw_XAqFxaMg';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  runApp(const VendozaApp());
}

class VendozaApp extends StatelessWidget {
  const VendozaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VENDOZA',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1457D9),
        ),
        useMaterial3: true,
      ),
      home: const AuthPage(),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isRegister = true;
  bool loading = false;
  String accountType = 'buyer';
  String message = '';

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.length < 6) {
      setState(() {
        message = 'Introdu e-mailul și o parolă de minimum 6 caractere.';
      });
      return;
    }

    setState(() {
      loading = true;
      message = '';
    });

    try {
      final auth = Supabase.instance.client.auth;

      if (isRegister) {
        final result = await auth.signUp(
          email: email,
          password: password,
          data: {'account_type': accountType},
        );

        if (result.session == null) {
          message = 'Verifică e-mailul și confirmă contul VENDOZA.';
        } else {
          message = 'Cont creat cu succes!';
        }
      } else {
        await auth.signInWithPassword(
          email: email,
          password: password,
        );
        message = 'Te-ai conectat cu succes!';
      }
    } on AuthException catch (e) {
      message = e.message;
    } catch (_) {
      message = 'A apărut o eroare. Încearcă din nou.';
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.shopping_bag,
                    size: 65,
                    color: Color(0xFF1457D9),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'VENDOZA',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1457D9),
                    ),
                  ),
                  const Text('Buy. Sell. Discover.'),
                  const SizedBox(height: 25),
                  Text(
                    isRegister ? 'Creează un cont' : 'Conectare',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Adresa de e-mail',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Parolă',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  if (isRegister) ...[
                    const SizedBox(height: 18),
                    const Text('Alege tipul contului'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: accountType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'buyer',
                          child: Text('Cumpărător'),
                        ),
                        DropdownMenuItem(
                          value: 'seller',
                          child: Text('Vânzător'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => accountType = value);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading ? null : submit,
                      child: Text(
                        loading
                            ? 'Se procesează...'
                            : isRegister
                                ? 'Înregistrare'
                                : 'Conectare',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        isRegister = !isRegister;
                        message = '';
                      });
                    },
                    child: Text(
                      isRegister
                          ? 'Am deja cont – Conectare'
                          : 'Nu am cont – Înregistrare',
                    ),
                  ),
                  if (message.isNotEmpty)
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.blue),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
