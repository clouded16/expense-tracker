import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/sqlite3.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Profile,
  Categories,
  Merchants,
  Expenses,
  Budgets,
  Goals,
  InvestmentAssets,
  PriceCache,
  SharedSpaces,
  SyncLog,
  CoachingFeed,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed(this);
        },
      );
}

Future<void> _seed(AppDatabase db) async {
  await db.into(db.profile).insert(
        const ProfileCompanion(name: Value('Me')),
        mode: InsertMode.insertOrIgnore,
      );

  const defaults = [
    ('Food', 'restaurant', '#F59E0B'),
    ('Transport', 'directions_car', '#3B82F6'),
    ('Shopping', 'shopping_bag', '#8B5CF6'),
    ('Bills', 'receipt_long', '#EF4444'),
    ('Medical', 'local_hospital', '#10B981'),
    ('Entertainment', 'movie', '#EC4899'),
    ('Groceries', 'local_grocery_store', '#22C55E'),
    ('Other', 'category', '#6B7280'),
  ];

  for (final (name, icon, color) in defaults) {
    await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: name,
            icon: Value(icon),
            color: Value(color),
            isDefault: const Value(true),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }
}

LazyDatabase openEncryptedDatabase(String passphrase) {
  return LazyDatabase(() async {
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'cashscope.db'));

    final db = sqlite3.open(file.path);
    db.execute("PRAGMA key = '${passphrase.replaceAll("'", "''")}';");
    db.execute('PRAGMA cipher_compatibility = 4;');
    db.dispose();

    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        rawDb.execute("PRAGMA key = '${passphrase.replaceAll("'", "''")}';");
        rawDb.execute('PRAGMA cipher_compatibility = 4;');
        rawDb.execute('PRAGMA foreign_keys = ON;');
      },
    );
  });
}
