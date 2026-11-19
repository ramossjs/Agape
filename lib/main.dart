import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_service.dart';
import 'firebase_options.dart';
import 'registration_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AgapeApp());
}

const green = Color(0xFF104D3C);
const cream = Color(0xFFF7F8F3);
const lime = Color(0xFFEAF2E5);
const orange = Color(0xFFEE8D42);

bool get mobilePreview =>
    !kIsWeb || Uri.base.queryParameters['mode'] == 'mobile';

enum UserRole { cliente, comercio, banco, admin, moderador }

class Offer {
  final String id, name, merchant, category, units, allergens, storage, address;
  final double kg, price, original, distance;
  final int categoryCode;
  String status;

  Offer({
    required this.id,
    required this.name,
    required this.merchant,
    required this.category,
    required this.units,
    required this.allergens,
    required this.storage,
    required this.address,
    required this.kg,
    required this.price,
    required this.original,
    required this.distance,
    required this.status,
    required this.categoryCode,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'merchant': merchant,
    'category': category,
    'units': units,
    'allergens': allergens,
    'storage': storage,
    'address': address,
    'kg': kg,
    'price': price,
    'original': original,
    'distance': distance,
    'status': status,
    'categoryCode': categoryCode,
  };

  factory Offer.fromJson(Map<String, dynamic> json) => Offer(
    id: json['id'],
    name: json['name'],
    merchant: json['merchant'],
    category: json['category'],
    units: json['units'],
    allergens: json['allergens'],
    storage: json['storage'],
    address: json['address'],
    kg: (json['kg'] as num).toDouble(),
    price: (json['price'] as num).toDouble(),
    original: (json['original'] as num).toDouble(),
    distance: (json['distance'] as num).toDouble(),
    status: json['status'],
    categoryCode: json['categoryCode'] ?? 0,
  );
}

class Operation {
  final String id, offerId, code, kind;
  final double price;
  String status;

  Operation({
    required this.id,
    required this.offerId,
    required this.code,
    required this.kind,
    required this.price,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'offerId': offerId,
    'code': code,
    'kind': kind,
    'price': price,
    'status': status,
  };

  factory Operation.fromJson(Map<String, dynamic> json) => Operation(
    id: json['id'],
    offerId: json['offerId'],
    code: json['code'],
    kind: json['kind'],
    price: (json['price'] as num).toDouble(),
    status: json['status'],
  );
}

class Report {
  final String id, offerId, reason, evidence;
  String status;
  String resolution;

  Report({
    required this.id,
    required this.offerId,
    required this.reason,
    required this.evidence,
    this.status = 'pending',
    this.resolution = '',
  });
}

class InventoryLot {
  final String id, name, origin;
  final double kg, remaining;
  String evidence;

  InventoryLot({
    required this.id,
    required this.name,
    required this.origin,
    required this.kg,
    required this.remaining,
    required this.evidence,
  });
}

class AidRequest {
  final String id, beneficiary, detail;
  final int people;
  String status;
  String? note;

  AidRequest({
    required this.id,
    required this.beneficiary,
    required this.detail,
    required this.people,
    required this.status,
    this.note,
  });
}

class CollectionRoute {
  final String id, name;
  final List<String> operationIds;
  bool completed;

  CollectionRoute({
    required this.id,
    required this.name,
    required this.operationIds,
    this.completed = false,
  });
}

class AgapeApp extends StatelessWidget {
  const AgapeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ágape',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: green),
        scaffoldBackgroundColor: cream,
      ),
      home: const AppShell(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onLogin,
    required this.onCredentialsLogin,
    required this.onPasswordReset,
  });
  final ValueChanged<UserRole> onLogin;
  final Future<void> Function(String email, String password) onCredentialsLogin;
  final Future<void> Function(String email) onPasswordReset;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loggingIn = false;

  void _openRegistration() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RegistrationPage(
          onRegistered: (user) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => EmailVerificationPage(
                  user: user,
                  onVerified: () => Navigator.of(context).pop(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String label(UserRole role) => switch (role) {
    UserRole.cliente => 'Cliente',
    UserRole.comercio => 'Comercio',
    UserRole.banco => 'Banco',
    UserRole.admin => 'Administrador',
    UserRole.moderador => 'Moderador',
  };

  @override
  Widget build(BuildContext context) {
    final roles = mobilePreview
        ? const [
            UserRole.cliente,
            UserRole.comercio,
            UserRole.banco,
            UserRole.admin,
            UserRole.moderador,
          ]
        : const [UserRole.admin, UserRole.moderador];
    final form = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mobilePreview) ...[
                Center(child: Image.asset('assets/agape.png', height: 96)),
                const SizedBox(height: 10),
              ],
              const Text(
                'BIENVENIDO A ÁGAPE',
                style: TextStyle(
                  color: Color(0xFF61806C),
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                !mobilePreview
                    ? 'Qué gusto verte por aquí'
                    : 'Alimentos que conectan',
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.15,
                  color: green,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                !mobilePreview
                    ? 'Inicia sesión o elige un perfil administrativo de prueba.'
                    : 'Inicia sesión o elige un perfil para explorar la demostración.',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loggingIn
                      ? null
                      : () async {
                          if (_email.text.trim().isEmpty ||
                              _password.text.isEmpty) {
                            return;
                          }
                          setState(() => _loggingIn = true);
                          try {
                            await widget.onCredentialsLogin(
                              _email.text,
                              _password.text,
                            );
                          } finally {
                            if (mounted) {
                              setState(() => _loggingIn = false);
                            }
                          }
                        },
                  child: _loggingIn
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Iniciar sesión'),
                ),
              ),
              TextButton(
                onPressed: () async {
                  if (_email.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Escribe tu correo para recuperarlo.'),
                      ),
                    );
                    return;
                  }
                  await widget.onPasswordReset(_email.text);
                },
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _openRegistration,
                  child: const Text('Crear una cuenta'),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Perfiles de demostración',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...roles.map(
                (role) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => widget.onLogin(role),
                    borderRadius: BorderRadius.circular(10),
                    child: Ink(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE4E8E1)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            role == UserRole.admin || role == UserRole.moderador
                                ? Icons.shield_outlined
                                : role == UserRole.comercio
                                ? Icons.store_outlined
                                : role == UserRole.banco
                                ? Icons.favorite_outline
                                : Icons.person_outline,
                            color: green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label(role),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Acceder como ${label(role).toLowerCase()}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Modelo local de demostración. No uses contraseñas ni datos reales.',
                style: TextStyle(color: Color(0xFF8B9584), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );

    if (mobilePreview) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(child: form),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return SafeArea(child: form);
          }

          final leftWidth = constraints.maxWidth * 0.5;
          final fontSize = leftWidth < 500 ? 32.0 : 42.0;
          return Row(
            children: [
              Expanded(
                child: Container(
                  color: const Color(0xFFEAF0DD),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 40,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset('assets/agape.png', height: 65),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ágape',
                                  style: TextStyle(
                                    color: green,
                                    fontSize: 25,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Alimentos que conectan',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Text(
                        'UN PEQUEÑO GESTO,\nUNA GRAN DIFERENCIA',
                        style: TextStyle(
                          color: Color(0xFF61806C),
                          fontSize: 11,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Menos desperdicio.\nMás oportunidades\npara compartir.',
                        style: TextStyle(
                          color: green,
                          height: 1.12,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Veracruz, México',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: form),
            ],
          );
        },
      ),
    );
  }
}

class _AdminDashboard extends StatelessWidget {
  const _AdminDashboard({required this.offers, required this.operations});
  final List<Offer> offers;
  final List<Operation> operations;

  @override
  Widget build(BuildContext context) {
    final delivered = operations
        .where((operation) => operation.status == 'delivered')
        .toList();
    final kg = delivered.fold<double>(
      0,
      (sum, operation) =>
          sum +
          (offers
                  .where((offer) => offer.id == operation.offerId)
                  .firstOrNull
                  ?.kg ??
              0),
    );
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Text(
          'Resumen general',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(color: green, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatCard(Icons.fastfood, '${offers.length}', 'Publicaciones'),
            _StatCard(Icons.receipt_long, '${operations.length}', 'Retiros'),
            _StatCard(Icons.check_circle, '${delivered.length}', 'Entregas'),
            _StatCard(
              Icons.eco,
              '${kg.toStringAsFixed(1)} kg',
              'Impacto entregado',
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.icon, this.value, this.label);
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: lime,
              foregroundColor: green,
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(label, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OffersAdminPage extends StatelessWidget {
  const _OffersAdminPage({required this.offers});
  final List<Offer> offers;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(28),
    children: [
      Text(
        'Publicaciones',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(color: green, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 16),
      Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Oferta')),
              DataColumn(label: Text('Comercio')),
              DataColumn(label: Text('Categoría')),
              DataColumn(label: Text('Estado')),
              DataColumn(label: Text('Peso')),
            ],
            rows: offers
                .map(
                  (offer) => DataRow(
                    cells: [
                      DataCell(Text(offer.name)),
                      DataCell(Text(offer.merchant)),
                      DataCell(Text(offer.category)),
                      DataCell(Text(offer.status)),
                      DataCell(Text('${offer.kg} kg')),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    ],
  );
}

class _ReportPage extends StatefulWidget {
  const _ReportPage({required this.reports, required this.offers});
  final List<Report> reports;
  final List<Offer> offers;

  @override
  State<_ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<_ReportPage> {
  void _resolve(Report report) {
    final controller = TextEditingController();
    var blockOffer = false;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Resolver reporte'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Motivo de la resolución',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: blockOffer,
                onChanged: (value) =>
                    setDialogState(() => blockOffer = value ?? false),
                title: const Text('Bloquear la publicación'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  report.status = 'resolved';
                  report.resolution = controller.text.trim();
                  if (blockOffer) {
                    final offer = widget.offers
                        .where((item) => item.id == report.offerId)
                        .firstOrNull;
                    if (offer != null) offer.status = 'blocked';
                  }
                });
                Navigator.pop(context);
              },
              child: const Text('Resolver'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reports.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(28),
        children: [
          Text(
            'Reportes y moderación',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: green, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'No hay reportes pendientes.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Text(
          'Reportes y moderación',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(color: green, fontWeight: FontWeight.w800),
        ),
        ...widget.reports.map(
          (report) => Card(
            child: ListTile(
              title: Text(report.reason),
              subtitle: Text(report.evidence),
              trailing: FilledButton(
                onPressed: report.status == 'pending'
                    ? () => _resolve(report)
                    : null,
                child: Text(
                  report.status == 'pending' ? 'Resolver' : 'Resuelto',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IndicatorsPage extends StatelessWidget {
  const _IndicatorsPage({required this.offers, required this.operations});
  final List<Offer> offers;
  final List<Operation> operations;

  @override
  Widget build(BuildContext context) {
    final delivered = operations
        .where((operation) => operation.status == 'delivered')
        .toList();
    final kg = delivered.fold<double>(
      0,
      (sum, operation) =>
          sum +
          (offers
                  .where((offer) => offer.id == operation.offerId)
                  .firstOrNull
                  ?.kg ??
              0),
    );
    final sale = delivered
        .where((operation) => operation.kind == 'sale')
        .length;
    final donation = delivered
        .where((operation) => operation.kind != 'sale')
        .length;
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Text(
          'El impacto de compartir',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(color: green, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        const Text(
          'Indicadores calculados a partir de los movimientos de esta demostración.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatCard(
              Icons.eco_outlined,
              '${kg.toStringAsFixed(1)} kg',
              'Alimentos rescatados',
            ),
            _StatCard(
              Icons.shopping_bag_outlined,
              '$sale',
              'Lotes vendidos y entregados',
            ),
            _StatCard(
              Icons.favorite_outline,
              '$donation',
              'Lotes donados y entregados',
            ),
            _StatCard(
              Icons.local_shipping_outlined,
              '${operations.where((operation) => operation.status == 'pending').length}',
              'Retiros pendientes',
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Destino de los alimentos',
                  style: TextStyle(
                    color: green,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                _ImpactBar('Venta a precio reducido', sale, green),
                _ImpactBar('Donación abierta', donation, orange),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ImpactBar extends StatelessWidget {
  const _ImpactBar(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label · $value lote(s)', style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: value == 0 ? 0 : value / (value + 1),
          minHeight: 10,
          color: color,
          backgroundColor: const Color(0xFFF0F4E9),
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    ),
  );
}

class _TracePage extends StatelessWidget {
  const _TracePage({required this.operations, required this.offers});
  final List<Operation> operations;
  final List<Offer> offers;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(28),
    children: [
      Text(
        'Trazabilidad',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(color: green, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 16),
      Card(
        child: operations.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Aún no hay movimientos registrados.',
                  textAlign: TextAlign.center,
                ),
              )
            : Column(
                children: operations.map((operation) {
                  final offer = offers
                      .where((item) => item.id == operation.offerId)
                      .firstOrNull;
                  return ListTile(
                    leading: const Icon(
                      Icons.check_circle_outline,
                      color: green,
                    ),
                    title: Text(offer?.name ?? operation.offerId),
                    subtitle: Text(
                      '${operation.id} · ${operation.status} · Código ${operation.code}',
                    ),
                  );
                }).toList(),
              ),
      ),
    ],
  );
}

class MobileShell extends StatelessWidget {
  const MobileShell({
    super.key,
    required this.role,
    required this.tab,
    required this.offers,
    required this.operations,
    required this.inventory,
    required this.aidRequests,
    required this.routes,
    required this.onTab,
    required this.onReserve,
    required this.onDeliver,
    required this.onAddPublication,
    required this.onAdvanceSale,
    required this.onAddAidRequest,
    required this.onAddDirectDonation,
    required this.onAddReport,
    required this.onReset,
    required this.onLogout,
  });

  final UserRole role;
  final int tab;
  final List<Offer> offers;
  final List<Operation> operations;
  final List<InventoryLot> inventory;
  final List<AidRequest> aidRequests;
  final List<CollectionRoute> routes;
  final ValueChanged<int> onTab;
  final ValueChanged<Offer> onReserve;
  final void Function(Operation, String) onDeliver;
  final void Function({
    required String name,
    required String category,
    required String units,
    required double kg,
    required double price,
    required double original,
  })
  onAddPublication;
  final ValueChanged<Offer> onAdvanceSale;
  final void Function({
    required String beneficiary,
    required String detail,
    required int people,
  })
  onAddAidRequest;
  final void Function({
    required String name,
    required String origin,
    required double kg,
  })
  onAddDirectDonation;
  final void Function({
    required String offerId,
    required String reason,
    required String evidence,
  })
  onAddReport;
  final VoidCallback onReset;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[];
    final destinations = <NavigationDestination>[];

    if (role == UserRole.cliente) {
      pages.addAll([
        CatalogPage(
          offers: offers,
          onReserve: onReserve,
          onReport: onAddReport,
        ),
        WithdrawalsPage(
          operations: operations,
          offers: offers,
          onDeliver: onDeliver,
        ),
        AidPage(requests: aidRequests, onCreate: onAddAidRequest),
        ProfilePage(onReset: onReset, onLogout: onLogout),
      ]);
      destinations.addAll(const [
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          label: 'Explorar',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'Mis retiros',
        ),
        NavigationDestination(
          icon: Icon(Icons.favorite_outline),
          label: 'Solicitar apoyo',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Perfil',
        ),
      ]);
    } else if (role == UserRole.comercio) {
      pages.addAll([
        RoleDashboardPage(
          role: role,
          offers: offers,
          operations: operations,
          onReset: onReset,
          onLogout: onLogout,
        ),
        CommercePublicationsPage(
          offers: offers,
          onAdd: onAddPublication,
          onAdvanceSale: onAdvanceSale,
        ),
        WithdrawalsPage(
          operations: operations,
          offers: offers,
          onDeliver: onDeliver,
        ),
        ProfilePage(onReset: onReset, onLogout: onLogout),
      ]);
      destinations.addAll(const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Mi panel',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'Publicaciones',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'Entregas',
        ),
        NavigationDestination(
          icon: Icon(Icons.store_outlined),
          label: 'Establecimiento',
        ),
      ]);
    } else {
      pages.addAll([
        RoleDashboardPage(
          role: role,
          offers: offers,
          operations: operations,
          onReset: onReset,
          onLogout: onLogout,
        ),
        CatalogPage(
          offers: offers,
          onReserve: onReserve,
          onReport: onAddReport,
        ),
        BankInventoryPage(
          inventory: inventory,
          operations: operations,
          onAddDirectDonation: onAddDirectDonation,
        ),
        WithdrawalsPage(
          operations: operations,
          offers: offers,
          onDeliver: onDeliver,
        ),
        BankAidPage(requests: aidRequests),
        ProfilePage(onReset: onReset, onLogout: onLogout),
      ]);
      destinations.addAll(const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Mi panel',
        ),
        NavigationDestination(
          icon: Icon(Icons.favorite_outline),
          label: 'Donaciones',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'Inventario',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'Retiros',
        ),
        NavigationDestination(
          icon: Icon(Icons.volunteer_activism_outlined),
          label: 'Solicitudes',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Perfil',
        ),
      ]);
    }
    final safeIndex = tab >= pages.length ? 0 : tab;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Row(
          children: [
            Image.asset('assets/agape.png', height: 42),
            const SizedBox(width: 6),
            const Text('Ágape', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: pages[safeIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: onTab,
        destinations: destinations,
      ),
    );
  }
}

class RoleDashboardPage extends StatelessWidget {
  const RoleDashboardPage({
    super.key,
    required this.role,
    required this.offers,
    required this.operations,
    required this.onReset,
    required this.onLogout,
  });

  final UserRole role;
  final List<Offer> offers;
  final List<Operation> operations;
  final VoidCallback onReset;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final commerce = role == UserRole.comercio;
    final pending = operations
        .where((operation) => operation.status == 'pending')
        .length;
    final delivered = operations
        .where((operation) => operation.status == 'delivered')
        .length;
    final kg = delivered.toDouble();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          commerce
              ? 'Tu comercio también hace la diferencia'
              : 'Conectamos alimentos con oportunidades',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: green,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 180,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0DD),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                commerce
                    ? 'Lo que te sobra,\na alguien le hace falta.'
                    : 'Cada recolección\nacerca un nuevo comienzo.',
                style: const TextStyle(
                  color: green,
                  fontSize: 24,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                commerce
                    ? 'Publica excedentes seguros y acompaña su entrega.'
                    : 'Organiza retiros y registra donativos.',
                style: const TextStyle(color: Color(0xFF6C7D62)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MobileStat(
              pending.toString(),
              commerce ? 'Retiros pendientes' : 'Recolecciones',
              Icons.local_shipping_outlined,
            ),
            _MobileStat(
              delivered.toString(),
              'Entregas completadas',
              Icons.check_circle_outline,
            ),
            _MobileStat(
              kg.toStringAsFixed(1),
              'Kilos rescatados',
              Icons.eco_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Accesos rápidos',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        const SizedBox(height: 10),
        ...[
          commerce
              ? ('Mis publicaciones', Icons.inventory_2_outlined)
              : ('Donativos e inventario', Icons.favorite_outline),
          commerce
              ? ('Entregas pendientes', Icons.receipt_long_outlined)
              : ('Rutas de recolección', Icons.route_outlined),
        ].map(
          (item) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(item.$2, color: green),
              title: Text(
                item.$1,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileStat extends StatelessWidget {
  const _MobileStat(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 155,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: green),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                color: green,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
}

class CommercePublicationsPage extends StatelessWidget {
  const CommercePublicationsPage({
    super.key,
    required this.offers,
    required this.onAdd,
    required this.onAdvanceSale,
  });

  final List<Offer> offers;
  final void Function({
    required String name,
    required String category,
    required String units,
    required double kg,
    required double price,
    required double original,
  })
  onAdd;
  final ValueChanged<Offer> onAdvanceSale;

  void _publish(BuildContext context) {
    final name = TextEditingController();
    final units = TextEditingController();
    final kg = TextEditingController(text: '1');
    final price = TextEditingController(text: '40');
    final original = TextEditingController(text: '100');
    var category = 'Panadería';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Publica una segunda oportunidad',
                  style: TextStyle(
                    fontSize: 20,
                    color: green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del producto',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  items:
                      const [
                            'Panadería',
                            'Frutas y verduras',
                            'Comida preparada',
                            'Lácteos',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) =>
                      setSheetState(() => category = value ?? category),
                  decoration: const InputDecoration(labelText: 'Categoría'),
                ),
                TextField(
                  controller: units,
                  decoration: const InputDecoration(
                    labelText: 'Contenido del lote',
                  ),
                ),
                TextField(
                  controller: kg,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Peso aproximado (kg)',
                  ),
                ),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Precio reducido MXN',
                  ),
                ),
                TextField(
                  controller: original,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Precio original MXN',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final kgValue = double.tryParse(kg.text);
                      final priceValue = double.tryParse(price.text);
                      final originalValue = double.tryParse(original.text);
                      if (name.text.trim().isEmpty ||
                          units.text.trim().isEmpty ||
                          kgValue == null ||
                          priceValue == null ||
                          originalValue == null ||
                          priceValue >= originalValue) {
                        return;
                      }
                      Navigator.pop(context);
                      onAdd(
                        name: name.text.trim(),
                        category: category,
                        units: units.text.trim(),
                        kg: kgValue,
                        price: priceValue,
                        original: originalValue,
                      );
                    },
                    child: const Text('Revisar y publicar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownOffers = offers
        .where((offer) => offer.merchant == 'Panadería La Espiga')
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Mis publicaciones',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(color: green, fontWeight: FontWeight.w800),
            ),
            FilledButton.icon(
              onPressed: () => _publish(context),
              icon: const Icon(Icons.add),
              label: const Text('Crear'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (ownOffers.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'Publica tu primer excedente',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ...ownOffers.map(
          (offer) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: lime,
                child: Icon(
                  offer.status == 'donation'
                      ? Icons.favorite
                      : Icons.bakery_dining,
                  color: green,
                ),
              ),
              title: Text(offer.name),
              subtitle: Text(
                '${offer.units} · ${offer.status == 'sale'
                    ? 'En venta'
                    : offer.status == 'donation'
                    ? 'Donación abierta'
                    : offer.status}',
              ),
              trailing: offer.status == 'sale'
                  ? TextButton(
                      onPressed: () => onAdvanceSale(offer),
                      child: const Text('Vencer venta'),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '“Vencer venta” adelanta el plazo para demostrar la conversión automática a donación.',
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }
}

class BankInventoryPage extends StatelessWidget {
  const BankInventoryPage({
    super.key,
    required this.inventory,
    required this.operations,
    required this.onAddDirectDonation,
  });

  final List<InventoryLot> inventory;
  final List<Operation> operations;
  final void Function({
    required String name,
    required String origin,
    required double kg,
  })
  onAddDirectDonation;

  void _add(BuildContext context) {
    final name = TextEditingController();
    final origin = TextEditingController();
    final kg = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Registrar donativo directo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Alimento'),
            ),
            TextField(
              controller: origin,
              decoration: const InputDecoration(labelText: 'Comercio u origen'),
            ),
            TextField(
              controller: kg,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad en kg'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final kgValue = double.tryParse(kg.text);
              if (name.text.trim().isEmpty ||
                  origin.text.trim().isEmpty ||
                  kgValue == null ||
                  kgValue <= 0) {
                return;
              }
              Navigator.pop(context);
              onAddDirectDonation(
                name: name.text.trim(),
                origin: origin.text.trim(),
                kg: kgValue,
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = inventory.fold<double>(
      0,
      (sum, lot) => sum + lot.remaining,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Donativos e inventario',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(color: green, fontWeight: FontWeight.w800),
            ),
            IconButton(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add_circle_outline, color: green),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: [
            _MobileStat(
              '${inventory.length}',
              'Lotes registrados',
              Icons.inventory_2_outlined,
            ),
            _MobileStat(
              available.toStringAsFixed(1),
              'kg disponibles',
              Icons.eco_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (inventory.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'El inventario empieza con un donativo',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ...inventory.map(
          (lot) => Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2, color: green),
              title: Text(lot.name),
              subtitle: Text(
                '${lot.origin} · ${lot.remaining.toStringAsFixed(1)} kg disponibles',
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ),
      ],
    );
  }
}

class AidPage extends StatelessWidget {
  const AidPage({super.key, required this.requests, required this.onCreate});
  final List<AidRequest> requests;
  final void Function({
    required String beneficiary,
    required String detail,
    required int people,
  })
  onCreate;

  void _create(BuildContext context) {
    final beneficiary = TextEditingController();
    final people = TextEditingController(text: '1');
    final detail = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nueva solicitud de apoyo',
              style: TextStyle(
                color: green,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextField(
              controller: beneficiary,
              decoration: const InputDecoration(
                labelText: 'Folio ficticio (BEN-001)',
              ),
            ),
            TextField(
              controller: people,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Personas a apoyar'),
            ),
            TextField(
              controller: detail,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Necesidad alimentaria',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final peopleValue = int.tryParse(people.text);
                  if (beneficiary.text.trim().isEmpty ||
                      detail.text.trim().isEmpty ||
                      peopleValue == null ||
                      peopleValue < 1) {
                    return;
                  }
                  Navigator.pop(context);
                  onCreate(
                    beneficiary: beneficiary.text.trim(),
                    detail: detail.text.trim(),
                    people: peopleValue,
                  );
                },
                child: const Text('Enviar solicitud'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Apoyo alimentario',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: green, fontWeight: FontWeight.w800),
          ),
          IconButton(
            onPressed: () => _create(context),
            icon: const Icon(Icons.add_circle, color: green),
          ),
        ],
      ),
      if (requests.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'No hay solicitudes registradas',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ...requests.map(
        (request) => Card(
          child: ListTile(
            leading: const Icon(Icons.favorite_outline, color: green),
            title: Text(request.id),
            subtitle: Text(
              '${request.detail}\n${request.people} persona(s) · ${request.beneficiary}',
            ),
            isThreeLine: true,
            trailing: Chip(
              label: Text(
                request.status == 'pending' ? 'Por revisar' : request.status,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class BankAidPage extends StatelessWidget {
  const BankAidPage({super.key, required this.requests});
  final List<AidRequest> requests;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        'Solicitudes de apoyo',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(color: green, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'Flujo complementario del modelo: elegibilidad y asignación deben definirse antes de producción.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ),
      if (requests.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'No hay solicitudes pendientes',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ...requests.map(
        (request) => Card(
          child: ListTile(
            title: Text(request.id),
            subtitle: Text(
              '${request.detail}\n${request.people} persona(s) · Beneficiario ${request.beneficiary}',
            ),
            isThreeLine: true,
            trailing: Text(request.status),
          ),
        ),
      ),
    ],
  );
}

class CatalogPage extends StatefulWidget {
  const CatalogPage({
    super.key,
    required this.offers,
    required this.onReserve,
    required this.onReport,
  });
  final List<Offer> offers;
  final ValueChanged<Offer> onReserve;
  final void Function({
    required String offerId,
    required String reason,
    required String evidence,
  })
  onReport;

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  String mode = 'todos';
  String search = '';
  String category = 'Todas';
  double maxDistance = 10;
  bool mapView = false;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.offers.where((offer) {
      final matchesMode =
          mode == 'todos' ||
          (mode == 'venta' && offer.status == 'sale') ||
          (mode == 'donacion' && offer.status == 'donation');
      final matchesSearch =
          search.isEmpty ||
          '${offer.name} ${offer.merchant}'.toLowerCase().contains(
            search.toLowerCase(),
          );
      final matchesCategory = category == 'Todas' || offer.category == category;
      final matchesDistance = offer.distance <= maxDistance;
      return matchesMode && matchesSearch && matchesCategory && matchesDistance;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Un buen día para rescatar',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: green, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (value) => setState(() => search = value),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Busca alimentos o comercios',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todos'),
              selected: mode == 'todos',
              onSelected: (_) => setState(() => mode = 'todos'),
            ),
            ChoiceChip(
              label: const Text('Precio reducido'),
              selected: mode == 'venta',
              onSelected: (_) => setState(() => mode = 'venta'),
            ),
            ChoiceChip(
              label: const Text('Donaciones'),
              selected: mode == 'donacion',
              onSelected: (_) => setState(() => mode = 'donacion'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: category,
                items:
                    const [
                          'Todas',
                          'Panadería',
                          'Frutas y verduras',
                          'Comida preparada',
                          'Lácteos',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) =>
                    setState(() => category = value ?? 'Todas'),
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            DropdownButton<double>(
              value: maxDistance,
              items: const [1, 2, 5, 10]
                  .map(
                    (value) => DropdownMenuItem<double>(
                      value: value.toDouble(),
                      child: Text('≤ ${value.toString()} km'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => maxDistance = value ?? 10),
            ),
            IconButton(
              tooltip: mapView ? 'Ver lista' : 'Ver mapa',
              onPressed: () => setState(() => mapView = !mapView),
              icon: Icon(mapView ? Icons.list : Icons.map_outlined),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (mapView)
          Container(
            height: 360,
            decoration: BoxDecoration(
              color: const Color(0xFFE6EDDF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE4E8E1)),
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFDCE9D4), Color(0xFFC8DFE3)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Mapa ilustrativo · Veracruz',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                ...filtered.asMap().entries.map((entry) {
                  final index = entry.key;
                  final offer = entry.value;
                  return Positioned(
                    left: 30.0 + (index % 3) * 110,
                    top: 40.0 + (index ~/ 3) * 90,
                    child: ActionChip(
                      avatar: const Icon(
                        Icons.location_pin,
                        size: 16,
                        color: green,
                      ),
                      label: Text(
                        offer.status == 'donation'
                            ? 'Donación'
                            : '\$${offer.price.toStringAsFixed(0)}',
                      ),
                      onPressed: () => _showDetail(context, offer),
                    ),
                  );
                }),
              ],
            ),
          )
        else
          ...filtered.map(
            (offer) => Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _showDetail(context, offer),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: lime,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          offer.categoryCode == 0
                              ? Icons.bakery_dining
                              : offer.categoryCode == 2
                              ? Icons.restaurant
                              : Icons.eco,
                          color: green,
                          size: 36,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              offer.merchant,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              offer.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${offer.units} · ${offer.distance} km',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              offer.status == 'donation'
                                  ? 'Donación abierta'
                                  : '\$${offer.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: green,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showDetail(BuildContext context, Offer offer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 22,
          right: 22,
          top: 22,
          bottom: MediaQuery.of(context).viewInsets.bottom + 22,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                offer.name,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(offer.merchant),
              const Divider(height: 28),
              _DetailRow('Cantidad', offer.units),
              _DetailRow('Peso', '${offer.kg} kg'),
              _DetailRow('Alérgenos', offer.allergens),
              _DetailRow('Conservación', offer.storage),
              _DetailRow('Retiro', offer.address),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: ['sale', 'donation'].contains(offer.status)
                      ? () {
                          Navigator.pop(context);
                          widget.onReserve(offer);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Retiro confirmado. Generamos tu folio y código.',
                              ),
                            ),
                          );
                        }
                      : null,
                  child: Text(
                    offer.status == 'donation'
                        ? 'Reclamar donación'
                        : 'Reservar por \$${offer.price.toStringAsFixed(0)}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value),
      ],
    ),
  );
}

class WithdrawalsPage extends StatelessWidget {
  const WithdrawalsPage({
    super.key,
    required this.operations,
    required this.offers,
    required this.onDeliver,
  });

  final List<Operation> operations;
  final List<Offer> offers;
  final void Function(Operation, String) onDeliver;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Mis retiros',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: green, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        if (operations.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Aún no tienes reservas',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Explora alimentos y confirma tu primer rescate.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ...operations.map((operation) {
          final offer = offers.firstWhere((o) => o.id == operation.offerId);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${operation.id} · ${operation.status}'),
                  if (operation.status == 'pending') ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Código de retiro',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      operation.code,
                      style: const TextStyle(
                        color: green,
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                        letterSpacing: 5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => _confirmDelivery(context, operation),
                      child: const Text('Comercio: confirmar entrega'),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _confirmDelivery(BuildContext context, Operation operation) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar entrega'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Código de seis dígitos',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onDeliver(operation, controller.text);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.onReset, required this.onLogout});
  final VoidCallback onReset;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const CircleAvatar(
          radius: 38,
          backgroundColor: lime,
          child: Text(
            'LD',
            style: TextStyle(
              color: green,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Lino Damián',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text('Cliente', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: const Icon(Icons.refresh, color: green),
          title: const Text('Reiniciar demostración'),
          onTap: onReset,
        ),
        const SizedBox(height: 10),
        ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Cerrar sesión'),
          onTap: onLogout,
        ),
      ],
    );
  }
}

class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    required this.role,
    required this.offers,
    required this.operations,
    required this.reports,
    required this.inventory,
    required this.aidRequests,
    required this.routes,
    required this.onReset,
    required this.onLogout,
  });

  final UserRole role;
  final List<Offer> offers;
  final List<Operation> operations;
  final List<Report> reports;
  final List<InventoryLot> inventory;
  final List<AidRequest> aidRequests;
  final List<CollectionRoute> routes;
  final VoidCallback onReset;
  final VoidCallback onLogout;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final items = widget.role == UserRole.moderador
        ? const [
            (Icons.flag_outlined, 'Reportes y moderación'),
            (Icons.inventory_2_outlined, 'Publicaciones'),
            (Icons.timeline_outlined, 'Trazabilidad'),
          ]
        : const [
            (Icons.grid_view_outlined, 'Resumen general'),
            (Icons.flag_outlined, 'Reportes y moderación'),
            (Icons.inventory_2_outlined, 'Publicaciones'),
            (Icons.timeline_outlined, 'Trazabilidad'),
            (Icons.bar_chart_outlined, 'Indicadores'),
          ];

    final body = switch (selected) {
      1 =>
        widget.role == UserRole.moderador
            ? _OffersAdminPage(offers: widget.offers)
            : _ReportPage(reports: widget.reports, offers: widget.offers),
      2 =>
        widget.role == UserRole.moderador
            ? _TracePage(operations: widget.operations, offers: widget.offers)
            : _OffersAdminPage(offers: widget.offers),
      3 => _TracePage(operations: widget.operations, offers: widget.offers),
      4 => _IndicatorsPage(
        offers: widget.offers,
        operations: widget.operations,
      ),
      _ =>
        widget.role == UserRole.moderador
            ? _ReportPage(reports: widget.reports, offers: widget.offers)
            : _AdminDashboard(
                offers: widget.offers,
                operations: widget.operations,
              ),
    };

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 76,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Row(
          children: [
            Image.asset('assets/agape.png', height: 48),
            const SizedBox(width: 8),
            const Text('Ágape', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: lime,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.role == UserRole.moderador ? 'Moderador' : 'Administrador',
              style: const TextStyle(
                color: green,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: widget.onReset,
            icon: const Icon(Icons.refresh),
            label: const Text('Reiniciar'),
          ),
          TextButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Salir'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            Container(
              width: 232,
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                    child: Text(
                      widget.role == UserRole.moderador
                          ? 'MODERACIÓN'
                          : 'ADMINISTRADOR',
                      style: const TextStyle(
                        color: Color(0xFF929B95),
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ...List.generate(items.length, (index) {
                    final item = items[index];
                    final active = selected == index;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      child: InkWell(
                        onTap: () => setState(() => selected = index),
                        borderRadius: BorderRadius.circular(9),
                        child: Ink(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: active ? lime : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.$1,
                                size: 19,
                                color: active ? green : const Color(0xFF748078),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.$2,
                                  style: TextStyle(
                                    color: active
                                        ? green
                                        : const Color(0xFF748078),
                                    fontSize: 13,
                                    fontWeight: active
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const Spacer(),
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7EE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE6ECDB)),
                    ),
                    child: const Text(
                      'Cada alimento cuenta.\nLo que se rescata hoy puede hacer la diferencia.',
                      style: TextStyle(color: green, height: 1.5, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  UserRole? role;
  int tab = 0;
  List<Offer> offers = [];
  List<Operation> operations = [];
  List<Report> reports = [];
  List<InventoryLot> inventory = [];
  List<AidRequest> aidRequests = [];
  List<CollectionRoute> routes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Offer> seedOffers() => [
    Offer(
      id: 'of-pan',
      name: 'Canasta de pan artesanal',
      merchant: 'Panadería La Espiga',
      category: 'Panadería',
      units: '6 piezas variadas',
      allergens: 'Gluten, huevo y leche',
      storage: 'Lugar fresco y seco.',
      address: 'Av. Independencia 112, Centro',
      kg: 1.2,
      price: 45,
      original: 120,
      distance: 0.8,
      status: 'sale',
      categoryCode: 0,
    ),
    Offer(
      id: 'of-veg',
      name: 'Verduras de la huerta',
      merchant: 'Frutería Don Pepe',
      category: 'Frutas y verduras',
      units: '1 canasta de 3 kg',
      allergens: 'Sin alérgenos declarados',
      storage: 'Refrigerar y lavar antes de consumir.',
      address: 'Calle Canal 245, Centro',
      kg: 3,
      price: 35,
      original: 85,
      distance: 1.2,
      status: 'donation',
      categoryCode: 1,
    ),
    Offer(
      id: 'of-comida',
      name: 'Comida casera para compartir',
      merchant: 'Cocina Doña Rosa',
      category: 'Comida preparada',
      units: '2 porciones completas',
      allergens: 'Puede contener leche y soya',
      storage: 'Mantener refrigerada a 4 °C.',
      address: 'Av. Salvador Díaz Mirón 328',
      kg: 1.5,
      price: 55,
      original: 130,
      distance: 1.5,
      status: 'sale',
      categoryCode: 2,
    ),
    Offer(
      id: 'of-fruta',
      name: 'Fruta fresca de temporada',
      merchant: 'Mercado de la Huaca',
      category: 'Frutas y verduras',
      units: '1 lote de 2 kg',
      allergens: 'Sin alérgenos declarados',
      storage: 'Conservar fresca y lavar antes de consumir.',
      address: 'Calle Víctimas del 25 de Junio 80',
      kg: 2,
      price: 30,
      original: 75,
      distance: 2.1,
      status: 'sale',
      categoryCode: 1,
    ),
    Offer(
      id: 'of-lacteos',
      name: 'Selección de lácteos',
      merchant: 'Abarrotes El Puerto',
      category: 'Lácteos',
      units: '3 productos sellados',
      allergens: 'Leche y derivados',
      storage: 'Cadena de frío a 4 °C.',
      address: 'Av. 20 de Noviembre 615',
      kg: 1.4,
      price: 40,
      original: 110,
      distance: 2.8,
      status: 'donation',
      categoryCode: 3,
    ),
  ];

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawOffers = prefs.getString('agape_offers');
    offers = rawOffers == null
        ? seedOffers()
        : (jsonDecode(rawOffers) as List)
              .map((item) => Offer.fromJson(Map<String, dynamic>.from(item)))
              .toList();
    final rawOperations = prefs.getString('agape_operations');
    if (rawOperations != null) {
      operations = (jsonDecode(rawOperations) as List)
          .map((item) => Operation.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    setState(() => loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'agape_offers',
      jsonEncode(offers.map((o) => o.toJson()).toList()),
    );
    await prefs.setString(
      'agape_operations',
      jsonEncode(operations.map((o) => o.toJson()).toList()),
    );
  }

  void reserve(Offer offer) {
    if (!['sale', 'donation'].contains(offer.status)) {
      _snack('Esta publicación ya no está disponible.');
      return;
    }
    if (operations.any((op) => op.offerId == offer.id)) {
      _snack('Esta publicación ya tiene un retiro activo.');
      return;
    }
    final code = (100000 + Random().nextInt(900000)).toString();
    final operation = Operation(
      id: 'RES-${DateTime.now().millisecondsSinceEpoch}',
      offerId: offer.id,
      code: code,
      kind: offer.status,
      price: offer.status == 'sale' ? offer.price : 0,
      status: 'pending',
    );
    setState(() {
      operations.insert(0, operation);
      offer.status = operation.kind == 'sale' ? 'reserved' : 'claimed';
    });
    _save();
  }

  void deliver(Operation operation, String code) {
    if (operation.status == 'delivered') {
      _snack('Este retiro ya fue entregado.');
      return;
    }
    if (operation.code != code) {
      _snack('El código no coincide.');
      return;
    }
    setState(() {
      operation.status = 'delivered';
      offers.firstWhere((o) => o.id == operation.offerId).status = 'delivered';
    });
    _save();
    _snack('Entrega confirmada.');
  }

  void reset() {
    setState(() {
      offers = seedOffers();
      operations.clear();
      reports.clear();
      inventory.clear();
      aidRequests.clear();
      routes.clear();
    });
    _save();
  }

  void addPublication({
    required String name,
    required String category,
    required String units,
    required double kg,
    required double price,
    required double original,
  }) {
    setState(() {
      offers.insert(
        0,
        Offer(
          id: 'OF-${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          merchant: role == UserRole.comercio
              ? 'Panadería La Espiga'
              : 'Ágape Veracruz',
          category: category,
          units: units,
          allergens: 'Consultar alérgenos',
          storage: 'Lugar fresco y seco.',
          address: 'Av. Independencia 112, Centro',
          kg: kg,
          price: price,
          original: original,
          distance: 0.8,
          status: 'sale',
          categoryCode: category == 'Panadería'
              ? 0
              : category == 'Comida preparada'
              ? 2
              : 1,
        ),
      );
    });
    _save();
  }

  void advanceSale(Offer offer) {
    setState(() => offer.status = 'donation');
    _save();
    _snack('Plazo vencido: la oferta pasó automáticamente a donación.');
  }

  void addAidRequest({
    required String beneficiary,
    required String detail,
    required int people,
  }) {
    setState(() {
      aidRequests.insert(
        0,
        AidRequest(
          id: 'APO-${DateTime.now().millisecondsSinceEpoch}',
          beneficiary: beneficiary,
          detail: detail,
          people: people,
          status: 'pending',
        ),
      );
    });
  }

  void addReport({
    required String offerId,
    required String reason,
    required String evidence,
  }) {
    setState(() {
      reports.insert(
        0,
        Report(
          id: 'REP-${DateTime.now().millisecondsSinceEpoch}',
          offerId: offerId,
          reason: reason,
          evidence: evidence,
        ),
      );
    });
  }

  void addDirectDonation({
    required String name,
    required String origin,
    required double kg,
  }) {
    setState(() {
      inventory.insert(
        0,
        InventoryLot(
          id: 'LOT-${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          origin: origin,
          kg: kg,
          remaining: kg,
          evidence: 'Recepción declarada apta para consumo.',
        ),
      );
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _passwordReset(String email) async {
    try {
      await AccountService().sendPasswordReset(email);
      _snack('Te enviamos un enlace para restablecer la contraseña.');
    } on FirebaseAuthException catch (error) {
      _snack(
        error.code == 'invalid-email'
            ? 'El correo no tiene un formato válido.'
            : 'No se pudo enviar el enlace de recuperación.',
      );
    }
  }

  Future<void> _credentialsLogin(String email, String password) async {
    try {
      final service = AccountService();
      await service.signIn(email: email, password: password);
      final user = service.auth.currentUser;
      if (user == null) throw FirebaseAuthException(code: 'no-user');

      await user.reload();
      if (!user.emailVerified) {
        await AccountService().resendVerificationEmail();
        _snack(
          'Verifica tu correo antes de entrar. Hemos enviado un nuevo enlace.',
        );
        await service.signOut();
        return;
      }

      final snapshot = await service.firestore
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snapshot.data();
      if (data == null) {
        throw FirebaseAuthException(code: 'user-profile-missing');
      }

      final accountRole = data['role'] as String?;
      final status = data['status'] as String?;
      if (accountRole != 'cliente' && status != 'activo') {
        _snack(
          'Tu cuenta institucional está pendiente de revisión administrativa.',
        );
        await service.signOut();
        return;
      }

      final selectedRole = switch (accountRole) {
        'cliente' => UserRole.cliente,
        'restaurante' => UserRole.comercio,
        'banco' => UserRole.banco,
        'moderador' => UserRole.moderador,
        'admin' => UserRole.admin,
        _ => null,
      };
      if (selectedRole == null) {
        _snack('Tu cuenta no tiene un rol válido.');
        await service.signOut();
        return;
      }
      setState(() => role = selectedRole);
      tab = 0;
    } on FirebaseAuthException catch (error) {
      _snack(switch (error.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'invalid-login-credentials' => 'Correo o contraseña incorrectos.',
        'user-not-found' => 'No existe una cuenta con ese correo.',
        'too-many-requests' => 'Demasiados intentos. Espera unos minutos.',
        'network-request-failed' => 'No hay conexión con Firebase.',
        'no-user' => 'No se pudo identificar tu cuenta.',
        'user-profile-missing' => 'No encontramos tu perfil en Firestore.',
        _ => 'No se pudo iniciar sesión. ${error.message ?? ''}',
      });
    } catch (_) {
      _snack('No se pudo iniciar sesión con Firebase.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (role == null) {
      return LoginPage(
        onLogin: (value) => setState(() => role = value),
        onCredentialsLogin: _credentialsLogin,
        onPasswordReset: _passwordReset,
      );
    }

    if (kIsWeb && !mobilePreview && role != UserRole.cliente) {
      return AdminShell(
        role: role!,
        offers: offers,
        operations: operations,
        reports: reports,
        inventory: inventory,
        aidRequests: aidRequests,
        routes: routes,
        onReset: reset,
        onLogout: () => setState(() => role = null),
      );
    }
    return MobileShell(
      role: role!,
      tab: tab,
      offers: offers,
      operations: operations,
      inventory: inventory,
      aidRequests: aidRequests,
      routes: routes,
      onTab: (value) => setState(() => tab = value),
      onReserve: reserve,
      onDeliver: deliver,
      onAddPublication: addPublication,
      onAdvanceSale: advanceSale,
      onAddAidRequest: addAidRequest,
      onAddDirectDonation: addDirectDonation,
      onAddReport: addReport,
      onReset: reset,
      onLogout: () => setState(() => role = null),
    );
  }
}
