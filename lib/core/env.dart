import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get apiBaseUrl {
    final v = dotenv.env['API_BASE_URL']?.trim();
    if (v == null || v.isEmpty) {
      throw StateError(
        'API_BASE_URL no definido. Añádelo al .env, p.ej.: API_BASE_URL=http://localhost:3000',
      );
    }
    return v;
  }
}
