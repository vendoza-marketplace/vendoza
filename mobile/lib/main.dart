
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://tlttresnklfdgaanjgwv.supabase.co';
const supabaseKey =
    'sb_publishable_54016q32muUvn9WcmfDkNw_XAqFxaMg';

const blue = Color(0xFF1457D9);
const darkBlue = Color(0xFF102B55);

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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
        scaffoldBackgroundColor: const Color(0xFFF5F7FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: darkBlue,
          elevation: 0,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = supabase.auth.currentUser;

        if (user != null) {
          return const HomePage();
        }

        return const LoginPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isRegister = false;
  bool loading = false;
  String accountType = 'buyer';

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.length < 6) {
      showMessage('Introdu emailul și o parolă de minimum 6 caractere.');
      return;
    }

    setState(() => loading = true);

    try {
      final auth = Supabase.instance.client.auth;

      if (isRegister) {
        final result = await auth.signUp(
          email: email,
          password: password,
          data: {'account_type': accountType},
        );

        if (result.session == null && mounted) {
          showMessage('Cont creat! Verifică emailul pentru confirmare.');
        }
      } else {
        await auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (mounted) {
          showMessage('Conectare reușită!');
        }
      }
    } on AuthException catch (e) {
      showMessage(e.message);
    } catch (e) {
      showMessage('Eroare de conectare. Verifică internetul.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.shopping_bag_rounded,
                    color: blue, size: 65),
                const SizedBox(height: 12),
                const Text(
                  'VENDOZA',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                    letterSpacing: 2,
                  ),
                ),
                const Text(
                  'Buy. Sell. Discover.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                Text(
                  isRegister ? 'Creează un cont' : 'Bine ai revenit!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Adresa de email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Parolă',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (isRegister) ...[
                  const SizedBox(height: 18),
                  const Text('Tipul contului'),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'buyer',
                        label: Text('Cumpărător'),
                        icon: Icon(Icons.shopping_cart_outlined),
                      ),
                      ButtonSegment(
                        value: 'seller',
                        label: Text('Vânzător'),
                        icon: Icon(Icons.storefront_outlined),
                      ),
                    ],
                    selected: {accountType},
                    onSelectionChanged: (value) {
                      setState(() => accountType = value.first);
                    },
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: loading ? null : submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: blue,
                    ),
                    child: loading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : Text(
                            isRegister ? 'Înregistrare' : 'Conectare',
                            style: const TextStyle(fontSize: 17),
                          ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => isRegister = !isRegister);
                  },
                  child: Text(
                    isRegister
                        ? 'Ai deja cont? Conectează-te'
                        : 'Nu ai cont? Înregistrează-te',
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final searchController = TextEditingController();
  String selectedCategory = 'Toate';

  final categories = [
    'Toate',
    'Telefoane',
    'Electronice',
    'Fashion',
    'Casă',
    'Auto',
    'Altele',
  ];

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Utilizator VENDOZA';

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shopping_bag_rounded, color: blue, size: 30),
            SizedBox(width: 8),
            Text(
              'VENDOZA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: darkBlue,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Profil',
            onPressed: () => showProfile(context, email),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(
            tooltip: 'Deconectare',
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [blue, darkBlue],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bine ai venit pe VENDOZA!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Cumpără, vinde și descoperă produse.',
                  style: TextStyle(color: Colors.white),
                ),
                SizedBox(height: 12),
                Text(
                  'Buy. Sell. Discover.',
                  style: TextStyle(
                    color: Colors.white70,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Ce produs cauți?',
              prefixIcon: const Icon(Icons.search, color: blue),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Categorii',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: categories.map((category) {
              return ChoiceChip(
                label: Text(category),
                selected: selectedCategory == category,
                selectedColor: blue.withOpacity(0.18),
                onSelected: (_) {
                  setState(() => selectedCategory = category);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: () {
                showMessage(
                  'Secțiunea de vânzare va fi conectată în pasul următor.',
                );
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text(
                'Vinde pe VENDOZA',
                style: TextStyle(fontSize: 16),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Produse noi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 48,
                  color: blue,
                ),
                SizedBox(height: 12),
                Text(
                  'Produsele vor apărea aici',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Pregătim catalogul VENDOZA pentru cumpărători și vânzători.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Center(
            child: Text(
              'VENDOZA © 2026',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void showProfile(BuildContext context, String email) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profilul meu',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                const Icon(
                  Icons.account_circle,
                  color: blue,
                  size: 55,
                ),
                const SizedBox(height: 8),
                Text(email),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      logout();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Deconectare'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
