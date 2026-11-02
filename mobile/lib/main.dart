import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://tlttresnklfdgaanjgwv.supabase.co';
const supabaseKey =
    'sb_publishable_54016q32muUvn9WcmfDkNw_XAqFxaMg';

const blue = Color(0xFF1457D9);
const darkBlue = Color(0xFF102B55);
const bucketName = 'product-images';

final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  runApp(const VendozaApp());
}

String makeUuid() {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));

  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final h = bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

Future<void> ensureProfile() async {
  final user = supabase.auth.currentUser;
  if (user == null) return;

  await supabase.from('profiles').upsert({
    'id': user.id,
    'account_type': 'individual',
  }, onConflict: 'id');
}

Future<void> becomeSeller() async {
  final user = supabase.auth.currentUser!;
  await ensureProfile();

  await supabase.from('seller_profiles').upsert({
    'user_id': user.id,
    'store_name': 'Magazin VENDOZA',
    'description': 'Magazin VENDOZA',
  }, onConflict: 'user_id');
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
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        return supabase.auth.currentUser == null
            ? const LoginPage()
            : const HomePage();
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
  final email = TextEditingController();
  final password = TextEditingController();

  bool register = false;
  bool loading = false;
  String accountType = 'buyer';

  void message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> submit() async {
    final e = email.text.trim();
    final p = password.text;

    if (e.isEmpty || p.length < 6) {
      message('Introdu emailul și o parolă de minimum 6 caractere.');
      return;
    }

    setState(() => loading = true);

    try {
      if (register) {
        final result = await supabase.auth.signUp(
          email: e,
          password: p,
          data: {'account_type': accountType},
        );

        if (result.user != null && result.session != null) {
          await ensureProfile();

          if (accountType == 'seller') {
            await becomeSeller();
          }

          message('Cont creat cu succes!');
        } else {
          message(
            'Cont creat! Confirmă adresa de email, apoi conectează-te.',
          );
        }
      } else {
        await supabase.auth.signInWithPassword(
          email: e,
          password: p,
        );

        await ensureProfile();
        message('Conectare reușită!');
      }
    } on AuthException catch (e) {
      message(e.message);
    } catch (e) {
      message('Eroare: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
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
                const Icon(
                  Icons.shopping_bag_rounded,
                  color: blue,
                  size: 65,
                ),
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
                const SizedBox(height: 30),
                Text(
                  register ? 'Creează un cont' : 'Bine ai revenit!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Adresa de email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Parolă',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (register) ...[
                  const SizedBox(height: 18),
                  const Text('Tipul contului'),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'buyer',
                        label: Text('Cumpărător'),
                      ),
                      ButtonSegment(
                        value: 'seller',
                        label: Text('Vânzător'),
                      ),
                    ],
                    selected: {accountType},
                    onSelectionChanged: (v) {
                      setState(() => accountType = v.first);
                    },
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: loading ? null : submit,
                    child: loading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : Text(
                            register ? 'Înregistrare' : 'Conectare',
                          ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => register = !register);
                  },
                  child: Text(
                    register
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
  bool isAdmin = false;
  bool checking = true;

  String category = 'Toate';
  final search = TextEditingController();

  final categories = [
    'Toate',
    'Electronice',
    'Moda',
    'Casa si gradina',
    'Sport',
    'Jucarii',
    'Auto',
  ];

  @override
  void initState() {
    super.initState();
    checkAdmin();
  }

  Future<void> checkAdmin() async {
    try {
      final result = await supabase.rpc('is_vendoza_admin');

      isAdmin = result == true;

      debugPrint('VENDOZA admin status: $isAdmin');
    } catch (e) {
      debugPrint('Eroare verificare administrator: $e');
      isAdmin = false;
    }

    if (mounted) {
      setState(() => checking = false);
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'VENDOZA',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: darkBlue,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          if (checking)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (isAdmin)
            IconButton(
              tooltip: 'Administrare',
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminPage(),
                  ),
                );
              },
            ),
          IconButton(
            tooltip: 'Profil',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (_) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(email),
                      const SizedBox(height: 15),
                      OutlinedButton(
                        onPressed: logout,
                        child: const Text('Deconectare'),
                      ),
                    ],
                  ),
                ),
              );
            },
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
                SizedBox(height: 10),
                Text(
                  'Buy. Sell. Discover.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: search,
            decoration: const InputDecoration(
              hintText: 'Ce produs cauți?',
              prefixIcon: Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          const Text(
            'Categorii',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: categories.map((c) {
              return ChoiceChip(
                label: Text(c),
                selected: category == c,
                onSelected: (_) {
                  setState(() => category = c);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SellPage(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Vinde pe VENDOZA'),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Produse disponibile',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ProductList(
            search: search.text,
            category: category,
          ),
          const SizedBox(height: 25),
          const Center(child: Text('VENDOZA © 2026')),
        ],
      ),
    );
  }
}

class ProductList extends StatelessWidget {
  final String search;
  final String category;

  const ProductList({
    super.key,
    required this.search,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final query = supabase.from('products').select(
      'id,name,description,price,currency,image_url,category_id,country',
    );

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: query
          .eq('status', 'approved')
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return const Text('Nu am putut încărca produsele.');
        }

        final items = (snapshot.data ?? []).where((p) {
          final name = (p['name'] ?? '').toString().toLowerCase();

          final matchesSearch =
              name.contains(search.toLowerCase());

          final matchesCategory = category == 'Toate' ||
              p['category_id'] == categoriesId(category);

          return matchesSearch && matchesCategory;
        }).toList();

        if (items.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Momentan nu există produse publicate.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Column(
          children: items.map((p) {
            return Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: p['image_url'] == null
                    ? const Icon(Icons.shopping_bag, size: 42)
                    : Image.network(
                        p['image_url'],
                        width: 65,
                        height: 65,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return const Icon(
                            Icons.image_not_supported,
                          );
                        },
                      ),
                title: Text(p['name'] ?? ''),
                subtitle: Text(
                  '${p['price']} lei\n${p['description'] ?? ''}',
                ),
                isThreeLine: true,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  int? categoriesId(String name) {
    const ids = {
      'Electronice': 1,
      'Moda': 2,
      'Casa si gradina': 3,
      'Sport': 4,
      'Jucarii': 5,
      'Auto': 6,
    };

    return ids[name];
  }
}

class SellPage extends StatefulWidget {
  const SellPage({super.key});

  @override
  State<SellPage> createState() => _SellPageState();
}

class _SellPageState extends State<SellPage> {
  final name = TextEditingController();
  final description = TextEditingController();
  final price = TextEditingController();
  final country = TextEditingController(text: 'Romania');

  final picker = ImagePicker();

  int categoryId = 1;
  XFile? image;
  bool loading = false;

  final categoryOptions = const {
    1: 'Electronice',
    2: 'Moda',
    3: 'Casa si gradina',
    4: 'Sport',
    5: 'Jucarii',
    6: 'Auto',
  };

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> chooseImage() async {
    try {
      final selected = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (selected != null) {
        setState(() => image = selected);
      }
    } catch (e) {
      message('Nu am putut deschide galeria: $e');
    }
  }

  Future<void> submitProduct() async {
    final user = supabase.auth.currentUser;

    final parsedPrice = double.tryParse(
      price.text.trim().replaceAll(',', '.'),
    );

    if (user == null) {
      message('Trebuie să fii conectat.');
      return;
    }

    if (name.text.trim().isEmpty ||
        parsedPrice == null ||
        parsedPrice <= 0) {
      message('Completează numele și un preț valid în lei.');
      return;
    }

    if (image == null) {
      message('Alege o fotografie pentru produs.');
      return;
    }

    setState(() => loading = true);

    try {
      await becomeSeller();

      final productId = makeUuid();

      final extension = image!.name.contains('.')
          ? image!.name.split('.').last.toLowerCase()
          : 'jpg';

      final path = '${user.id}/$productId.$extension';

      final bytes = await image!.readAsBytes();

      await supabase.storage.from(bucketName).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: image!.mimeType ?? 'image/jpeg',
          upsert: false,
        ),
      );

      final imageUrl =
          supabase.storage.from(bucketName).getPublicUrl(path);

      await supabase.from('products').insert({
        'id': productId,
        'seller_id': user.id,
        'category_id': categoryId,
        'name': name.text.trim(),
        'description': description.text.trim(),
        'price': parsedPrice,
        'currency': 'RON',
        'country': country.text.trim(),
        'image_url': imageUrl,
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (!mounted) return;

      message('Produs trimis! Așteaptă aprobarea administratorului.');
      Navigator.pop(context);
    } catch (e) {
      message('Eroare la publicarea produsului: $e');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
    country.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adaugă produs'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Fotografia produsului',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: chooseImage,
            child: Container(
              height: 190,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: blue),
              ),
              child: image == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 55,
                          color: blue,
                        ),
                        SizedBox(height: 8),
                        Text('Alege din galeria telefonului'),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(image!.path),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return const Center(
                            child: Icon(Icons.image, size: 60),
                          );
                        },
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: 'Numele produsului',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            value: categoryId,
            decoration: const InputDecoration(
              labelText: 'Categoria',
              border: OutlineInputBorder(),
            ),
            items: categoryOptions.entries.map((e) {
              return DropdownMenuItem(
                value: e.key,
                child: Text(e.value),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => categoryId = v);
              }
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: description,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Descriere',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: price,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Preț în lei (RON)',
              suffixText: 'lei',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: country,
            decoration: const InputDecoration(
              labelText: 'Țara',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: loading ? null : submitProduct,
              child: loading
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
                  : const Text('Trimite spre aprobare'),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Produsul va fi vizibil cumpărătorilor numai după aprobare.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  Future<List<Map<String, dynamic>>> loadPending() async {
    return await supabase
        .from('products')
        .select(
          'id,name,description,price,currency,image_url,country,seller_id',
        )
        .eq('status', 'pending')
        .order('created_at');
  }

  Future<void> approve(String id) async {
    try {
      await supabase.from('products').update({
        'status': 'approved',
      }).eq('id', id);

      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produs aprobat și publicat!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: $e')),
        );
      }
    }
  }

  Future<void> reject(String id) async {
    try {
      await supabase.from('products').update({
        'status': 'rejected',
      }).eq('id', id);

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrare VENDOZA'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: loadPending(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Eroare: ${snapshot.error}'),
            );
          }

          final products = snapshot.data ?? [];

          if (products.isEmpty) {
            return const Center(
              child: Text(
                'Nu există produse în așteptarea aprobării.',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final p = products[index];

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (p['image_url'] != null)
                        Image.network(
                          p['image_url'],
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return const Icon(
                              Icons.image_not_supported,
                              size: 60,
                            );
                          },
                        ),
                      const SizedBox(height: 10),
                      Text(
                        p['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('${p['price']} lei'),
                      Text(p['description'] ?? ''),
                      Text('Țara: ${p['country'] ?? ''}'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () => approve(p['id']),
                              child: const Text('Aprobă'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => reject(p['id']),
                              child: const Text('Respinge'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

}
