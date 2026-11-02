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
