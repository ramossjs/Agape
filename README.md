# Ágape

Aplicación Flutter para rescate y redistribución de excedentes alimentarios.

## Plataformas

- Android
- iOS
- Web

## Ejecutar

```bash
flutter pub get
flutter run -d chrome
```

Para probar la vista móvil web:

```text
http://localhost:8080/?mode=mobile
```

## Firebase

El proyecto utiliza Firebase Authentication y Cloud Firestore.

Antes de ejecutarlo en un equipo nuevo, configura FlutterFire con el proyecto correspondiente:

```bash
flutterfire configure
```

No subir claves privadas de administradores ni archivos de cuentas de servicio.
