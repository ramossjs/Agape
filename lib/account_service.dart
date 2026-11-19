import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum PublicAccountRole { cliente, restaurante, banco }

extension PublicAccountRoleData on PublicAccountRole {
  String get value => switch (this) {
    PublicAccountRole.cliente => 'cliente',
    PublicAccountRole.restaurante => 'restaurante',
    PublicAccountRole.banco => 'banco',
  };

  String get label => switch (this) {
    PublicAccountRole.cliente => 'Cliente',
    PublicAccountRole.restaurante => 'Restaurante',
    PublicAccountRole.banco => 'Banco de alimentos',
  };
}

class AccountRegistrationData {
  const AccountRegistrationData({
    required this.email,
    required this.password,
    required this.role,
    required this.fullName,
    required this.phone,
    required this.profile,
  });

  final String email;
  final String password;
  final PublicAccountRole role;
  final String fullName;
  final String phone;
  final Map<String, dynamic> profile;
}

class AccountService {
  AccountService([FirebaseAuth? auth, FirebaseFirestore? firestore])
    : _auth = auth,
      _firestore = firestore;

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;

  FirebaseAuth get auth => _auth ??= FirebaseAuth.instance;
  FirebaseFirestore get firestore => _firestore ??= FirebaseFirestore.instance;

  Future<User> register(AccountRegistrationData data) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: data.email.trim(),
      password: data.password,
    );
    final user = credential.user;
    if (user == null) throw FirebaseAuthException(code: 'no-user');

    await user.updateDisplayName(data.fullName);
    await user.sendEmailVerification();

    await firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': data.email.trim(),
      'fullName': data.fullName,
      'phone': data.phone,
      'role': data.role.value,
      'status': data.role == PublicAccountRole.cliente
          ? 'correo_no_verificado'
          : 'pendiente_revision',
      'emailVerified': false,
      'profile': data.profile,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return user;
  }

  Future<void> signIn({required String email, required String password}) async {
    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordReset(String email) async {
    await auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> resendVerificationEmail() async {
    final user = auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-user');
    await user.reload();
    if (user.emailVerified) return;
    await user.sendEmailVerification();
  }

  Future<void> refreshEmailVerification() async {
    final user = auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-user');
    await user.reload();
    final verified = user.emailVerified;
    if (!verified) return;

    final profile = await firestore.collection('users').doc(user.uid).get();
    final role = profile.data()?['role'] as String?;
    await firestore.collection('users').doc(user.uid).update({
      'emailVerified': true,
      'status': role == 'cliente' ? 'activo' : 'pendiente_revision',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> signOut() => auth.signOut();
}
