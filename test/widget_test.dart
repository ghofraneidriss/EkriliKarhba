import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekrili_karhba/features/users/domain/user.dart';
import 'package:ekrili_karhba/features/users/services/user_service.dart';
import 'package:ekrili_karhba/features/users/ui/login_screen.dart';
import 'package:ekrili_karhba/main.dart';

void main() {
  setUp(() {
    UserService.instance.setCurrentUser(
      User(
        id: 1,
        nom: 'Ben Amor',
        prenom: 'Yassine',
        email: 'admin@ekrili.tn',
        telephone: '20100200',
        motDePasse: 'hash',
        passwordSalt: 'salt',
        role: UserRole.admin,
        statut: UserStatus.actif,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      ),
    );
  });

  testWidgets('opens the maintenance dashboard when logged in', (tester) async {
    await tester.pumpWidget(const EkriliKarhbaApp());

    expect(find.text('Maintenance'), findsWidgets);
    expect(find.text('Maintenance urgente'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle maintenance'), findsOneWidget);
  });

  testWidgets('displays login screen when user is not authenticated', (tester) async {
    UserService.instance.setCurrentUser(null);
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Ekrili Karhba'), findsOneWidget);
    expect(find.text('Connexion à votre espace'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });
}
