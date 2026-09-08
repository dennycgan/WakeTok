import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:waketok/data/local/saved_pool_tables.dart';

part 'waketok_database.g.dart';

@DriftDatabase(tables: [SavedPools, SavedPoolSources])
class WaketokDatabase extends _$WaketokDatabase {
  WaketokDatabase(super.e);

  /// Product opener: `waketok.sqlite` under Application Support.
  factory WaketokDatabase.defaults() {
    return WaketokDatabase(
      driftDatabase(
        name: 'waketok',
        native: const DriftNativeOptions(
          databaseDirectory: getApplicationSupportDirectory,
        ),
      ),
    );
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) => m.createAll(),
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
