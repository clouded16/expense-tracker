import 'package:drift/drift.dart';

@DataClassName('ProfileRow')
class Profile extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withDefault(const Constant('Me'))();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  TextColumn get email => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('CategoryRow')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 64)();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {name},
      ];
}

@DataClassName('MerchantRow')
class Merchants extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 128)();
  TextColumn get defaultCategory => text().nullable()();
  IntColumn get usageCount => integer().withDefault(const Constant(0))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {name},
      ];
}

@DataClassName('ExpenseRow')
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  TextColumn get categoryName => text().nullable()();
  TextColumn get merchantName => text().nullable()();
  TextColumn get sourceName => text().withDefault(const Constant('manual'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get transactionDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  IntColumn get sharedSpaceId => integer().nullable()();
  RealColumn get splitRatioOverride => real().nullable()();
}

@DataClassName('BudgetRow')
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get categoryName => text().nullable()();
  RealColumn get monthlyAmount => real()();
  IntColumn get year => integer()();
  IntColumn get month => integer()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  IntColumn get sharedSpaceId => integer().nullable()();
}

@DataClassName('GoalRow')
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get targetAmount => real()();
  RealColumn get currentAmount => real().withDefault(const Constant(0))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  IntColumn get sharedSpaceId => integer().nullable()();
}

@DataClassName('InvestmentAssetRow')
class InvestmentAssets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get assetType => text()();
  TextColumn get name => text()();
  TextColumn get symbol => text().nullable()();
  RealColumn get units => real().withDefault(const Constant(0))();
  RealColumn get buyPrice => real().nullable()();
  RealColumn get latestPrice => real().nullable()();
  DateTimeColumn get latestPriceAt => dateTime().nullable()();
  TextColumn get metadata => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('PriceCacheRow')
class PriceCache extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get source => text()();
  TextColumn get symbol => text()();
  RealColumn get price => real()();
  TextColumn get raw => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {source, symbol},
      ];
}

@DataClassName('SharedSpaceRow')
class SharedSpaces extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get spaceUuid => text().unique()();
  TextColumn get name => text()();
  TextColumn get peerDeviceId => text().nullable()();
  TextColumn get peerName => text().nullable()();
  TextColumn get sharedSecret => text().nullable()();
  RealColumn get selfRatio => real().withDefault(const Constant(0.5))();
  RealColumn get peerRatio => real().withDefault(const Constant(0.5))();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('SyncLogRow')
class SyncLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sharedSpaceId => integer()();
  TextColumn get entityType => text()();
  IntColumn get entityId => integer()();
  TextColumn get operation => text()();
  TextColumn get payload => text().nullable()();
  DateTimeColumn get appliedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('CoachingFeedRow')
class CoachingFeed extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get title => text()();
  TextColumn get message => text()();
  TextColumn get severity => text().withDefault(const Constant('info'))();
  TextColumn get metadata => text().nullable()();
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get generatedAt => dateTime().withDefault(currentDateAndTime)();
}
