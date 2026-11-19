import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'account_service.dart';

const green = Color(0xFF104D3C);
const cream = Color(0xFFF7F8F3);

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key, required this.onRegistered});

  final void Function(User user) onRegistered;

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _birthDate = TextEditingController();
  final _postalCode = TextEditingController();
  final _colony = TextEditingController();
  final _allergens = TextEditingController();
  final _businessName = TextEditingController();
  final _legalName = TextEditingController();
  final _taxId = TextEditingController();
  final _businessAddress = TextEditingController();
  final _sanitaryDocument = TextEditingController();
  final _website = TextEditingController();
  final _responsibleName = TextEditingController();
  final _responsiblePosition = TextEditingController();

  PublicAccountRole role = PublicAccountRole.cliente;
  bool acceptedTerms = false;
  bool loading = false;

  @override
  void dispose() {
    for (final controller in [
      _email,
      _password,
      _confirmPassword,
      _fullName,
      _phone,
      _birthDate,
      _postalCode,
      _colony,
      _allergens,
      _businessName,
      _legalName,
      _taxId,
      _businessAddress,
      _sanitaryDocument,
      _website,
      _responsibleName,
      _responsiblePosition,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio';
    }
    return null;
  }

  String _authError(FirebaseAuthException error) => switch (error.code) {
    'email-already-in-use' => 'Ese correo ya está registrado.',
    'invalid-email' => 'El correo no tiene un formato válido.',
    'weak-password' => 'La contraseña debe ser más segura.',
    'network-request-failed' => 'No hay conexión con el servicio.',
    _ => 'No se pudo crear la cuenta. ${error.message ?? ''}',
  };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar los términos y el aviso de privacidad.'),
        ),
      );
      return;
    }
    if (_password.text != _confirmPassword.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden.')),
      );
      return;
    }

    setState(() => loading = true);
    try {
      final profile = switch (role) {
        PublicAccountRole.cliente => {
          'birthDate': _birthDate.text.trim(),
          'postalCode': _postalCode.text.trim(),
          'colony': _colony.text.trim(),
          'allergens': _allergens.text.trim(),
        },
        PublicAccountRole.restaurante => {
          'businessName': _businessName.text.trim(),
          'legalName': _legalName.text.trim(),
          'taxId': _taxId.text.trim(),
          'address': _businessAddress.text.trim(),
          'sanitaryDocument': _sanitaryDocument.text.trim(),
          'websiteOrSocialMedia': _website.text.trim(),
          'responsibleName': _responsibleName.text.trim(),
          'responsiblePosition': _responsiblePosition.text.trim(),
        },
        PublicAccountRole.banco => {
          'institutionName': _businessName.text.trim(),
          'legalName': _legalName.text.trim(),
          'taxId': _taxId.text.trim(),
          'address': _businessAddress.text.trim(),
          'sanitaryDocument': _sanitaryDocument.text.trim(),
          'websiteOrSocialMedia': _website.text.trim(),
          'responsibleName': _responsibleName.text.trim(),
          'responsiblePosition': _responsiblePosition.text.trim(),
        },
      };

      final user = await AccountService().register(
        AccountRegistrationData(
          email: _email.text,
          password: _password.text,
          role: role,
          fullName: _fullName.text,
          phone: _phone.text,
          profile: profile,
        ),
      );
      if (!mounted) return;
      widget.onRegistered(user);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_authError(error))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo completar el registro en Firebase.'),
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    bool optional = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        validator: optional ? null : _required,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Elige el tipo de cuenta',
                  style: TextStyle(
                    color: green,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: PublicAccountRole.values.map((value) {
                    return ChoiceChip(
                      label: Text(value.label),
                      selected: role == value,
                      onSelected: (_) => setState(() => role = value),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                _field(
                  _fullName,
                  role == PublicAccountRole.cliente
                      ? 'Nombre y apellidos'
                      : 'Nombre completo del responsable',
                ),
                _field(
                  _email,
                  'Correo electrónico',
                  keyboardType: TextInputType.emailAddress,
                ),
                _field(
                  _phone,
                  'Teléfono (opcional)',
                  keyboardType: TextInputType.phone,
                  optional: true,
                ),
                _field(_password, 'Contraseña', obscure: true),
                _field(_confirmPassword, 'Confirmar contraseña', obscure: true),
                if (role == PublicAccountRole.cliente) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _birthDate,
                      readOnly: true,
                      validator: _required,
                      decoration: const InputDecoration(
                        labelText: 'Fecha de nacimiento',
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      onTap: () async {
                        final now = DateTime.now();
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: DateTime(
                            now.year - 18,
                            now.month,
                            now.day,
                          ),
                          firstDate: DateTime(1900),
                          lastDate: now,
                        );
                        if (selected != null) {
                          _birthDate.text =
                              '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
                        }
                      },
                    ),
                  ),
                  _field(
                    _postalCode,
                    'Código postal (opcional)',
                    keyboardType: TextInputType.number,
                    optional: true,
                  ),
                  _field(
                    _colony,
                    'Colonia o comunidad (opcional)',
                    optional: true,
                  ),
                  _field(
                    _allergens,
                    'Alérgenos conocidos (opcional)',
                    optional: true,
                  ),
                ],
                if (role != PublicAccountRole.cliente) ...[
                  _field(_responsibleName, 'Nombre del responsable'),
                  _field(_responsiblePosition, 'Cargo del responsable'),
                  _field(
                    _businessName,
                    role == PublicAccountRole.restaurante
                        ? 'Nombre comercial'
                        : 'Nombre de la institución',
                  ),
                  _field(_legalName, 'Razón social'),
                  _field(_taxId, 'RFC'),
                  _field(_businessAddress, 'Dirección principal'),
                  _field(
                    _sanitaryDocument,
                    role == PublicAccountRole.restaurante
                        ? 'Permiso o constancia sanitaria'
                        : 'Constancia jurídica o registro aplicable',
                  ),
                  _field(
                    _website,
                    'Sitio web o redes sociales (opcional)',
                    optional: true,
                  ),
                ],
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: acceptedTerms,
                  onChanged: (value) =>
                      setState(() => acceptedTerms = value ?? false),
                  title: const Text(
                    'Acepto los términos y el aviso de privacidad.',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: loading ? null : _submit,
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Crear cuenta'),
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

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.user,
    required this.onVerified,
  });

  final User user;
  final VoidCallback onVerified;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool checking = false;
  bool sending = false;

  Future<void> _resend() async {
    setState(() => sending = true);
    try {
      await AccountService().resendVerificationEmail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reenviamos el enlace de verificación.')),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'No se pudo reenviar el correo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _check() async {
    setState(() => checking = true);
    try {
      await AccountService().refreshEmailVerification();
      await widget.user.reload();
      if (!mounted) return;
      if (widget.user.emailVerified) {
        widget.onVerified();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Todavía no verificamos el correo. Abre el enlace recibido.',
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'No se pudo comprobar la verificación.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text('Verifica tu correo'),
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 64,
                      color: green,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Revisa tu bandeja de entrada',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: green,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enviamos un enlace de verificación a ${widget.user.email ?? ''}.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: checking ? null : _check,
                        child: checking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Ya verificué mi correo'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: sending ? null : _resend,
                      child: const Text('Reenviar enlace'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
