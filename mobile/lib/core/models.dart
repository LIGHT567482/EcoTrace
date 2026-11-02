class Category {
  final int id;
  final String name;
  final List<ItemType> types;

  const Category({required this.id, required this.name, required this.types});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        types: (json['types'] as List<dynamic>? ?? [])
            .map((e) => ItemType.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ItemType {
  final int id;
  final int categoryId;
  final String name;
  final double rewardUgx;
  final double carbonFactorKg;
  final bool hazardous;
  final bool isActive;

  const ItemType({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.rewardUgx,
    this.carbonFactorKg = 1.0,
    this.hazardous = false,
    required this.isActive,
  });

  factory ItemType.fromJson(Map<String, dynamic> json) => ItemType(
        id: json['id'] as int? ?? 0,
        categoryId: json['category'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        rewardUgx: double.tryParse('${json['reward_ugx']}') ?? 0,
        carbonFactorKg: double.tryParse('${json['carbon_factor_kg'] ?? 1}') ?? 1,
        hazardous: json['hazardous'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
      );
}

class EwasteItem {
  final int id;
  final int itemTypeId;
  final String typeName;
  final String categoryName;
  final int quantity;
  final String condition;
  final String notes;
  final String rewardUgx;
  final double carbonKg;
  final bool hazardous;

  const EwasteItem({
    required this.id,
    required this.itemTypeId,
    required this.typeName,
    required this.categoryName,
    required this.quantity,
    required this.condition,
    required this.notes,
    required this.rewardUgx,
    this.carbonKg = 0,
    this.hazardous = false,
  });

  factory EwasteItem.fromJson(Map<String, dynamic> json) => EwasteItem(
        id: json['id'] as int? ?? 0,
        itemTypeId: json['item_type'] as int? ?? 0,
        typeName: json['type_name'] as String? ?? '',
        categoryName: json['category_name'] as String? ?? '',
        quantity: json['quantity'] as int? ?? 1,
        condition: json['condition'] as String? ?? 'BROKEN',
        notes: json['notes'] as String? ?? '',
        rewardUgx: '${json['reward_ugx'] ?? 0}',
        carbonKg: double.tryParse('${json['carbon_kg'] ?? 0}') ?? 0,
        hazardous: json['hazardous'] as bool? ?? false,
      );
}

class DropOffPoint {
  final int id;
  final String name;
  final String address;
  final String town;
  final String phone;
  final String openingHours;
  final double? latitude;
  final double? longitude;

  const DropOffPoint({
    required this.id,
    required this.name,
    required this.address,
    required this.town,
    required this.phone,
    required this.openingHours,
    this.latitude,
    this.longitude,
  });

  factory DropOffPoint.fromJson(Map<String, dynamic> json) => DropOffPoint(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        address: json['address'] as String? ?? '',
        town: json['town'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        openingHours: json['opening_hours'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
}

class RequestEvent {
  final int id;
  final String status;
  final String note;
  final String? actorName;
  final String createdAt;

  const RequestEvent({
    required this.id,
    required this.status,
    required this.note,
    this.actorName,
    required this.createdAt,
  });

  factory RequestEvent.fromJson(Map<String, dynamic> json) => RequestEvent(
        id: json['id'] as int? ?? 0,
        status: json['status'] as String? ?? '',
        note: json['note'] as String? ?? '',
        actorName: json['actor_name'] as String?,
        createdAt: json['created_at'] as String? ?? '',
      );
}

class Certificate {
  final String code;
  final String summary;
  final double carbonKg;

  const Certificate({
    required this.code,
    required this.summary,
    this.carbonKg = 0,
  });

  factory Certificate.fromJson(Map<String, dynamic> json) => Certificate(
        code: json['code'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        carbonKg: double.tryParse('${json['carbon_kg'] ?? 0}') ?? 0,
      );
}

class CollectionRequest {
  final int id;
  final String reference;
  final String requestType;
  final String status;
  final String statusLabel;
  final List<EwasteItem> items;
  final int itemCount;
  final String pickupAddress;
  final String? dropoffName;
  final bool rewardCredited;
  final String consumerName;
  final String? collectorName;
  final List<RequestEvent> events;
  final Certificate? certificate;
  final String createdAt;
  final double carbonKg;
  final int hazardousCount;

  const CollectionRequest({
    required this.id,
    required this.reference,
    required this.requestType,
    required this.status,
    required this.statusLabel,
    required this.items,
    required this.itemCount,
    required this.pickupAddress,
    this.dropoffName,
    required this.rewardCredited,
    required this.consumerName,
    this.collectorName,
    required this.events,
    this.certificate,
    required this.createdAt,
    this.carbonKg = 0,
    this.hazardousCount = 0,
  });

  factory CollectionRequest.fromJson(Map<String, dynamic> json) {
    final consumer = json['consumer_detail'] as Map<String, dynamic>?;
    return CollectionRequest(
      id: json['id'] as int? ?? 0,
      reference: json['reference'] as String? ?? '',
      requestType: json['request_type'] as String? ?? 'PICKUP',
      status: json['status'] as String? ?? '',
      statusLabel: json['status_label'] as String? ?? json['status'] as String? ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => EwasteItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      itemCount: json['item_count'] as int? ?? 0,
      pickupAddress: json['pickup_address'] as String? ?? '',
      dropoffName: (json['dropoff_point_detail'] as Map<String, dynamic>?)?['name']
          as String?,
      rewardCredited: json['reward_credited'] as bool? ?? false,
      consumerName: consumer == null
          ? ''
          : (consumer['full_name'] as String? ?? consumer['phone'] as String? ?? ''),
      collectorName: json['collector_name'] as String?,
      events: (json['events'] as List<dynamic>? ?? [])
          .map((e) => RequestEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      certificate: json['certificate'] == null
          ? null
          : Certificate.fromJson(json['certificate'] as Map<String, dynamic>),
      createdAt: json['created_at'] as String? ?? '',
      carbonKg: double.tryParse('${json['carbon_kg'] ?? 0}') ?? 0,
      hazardousCount: json['hazardous_count'] as int? ?? 0,
    );
  }
}

class Wallet {
  final double balance;
  final List<WalletTransaction> transactions;

  const Wallet({required this.balance, required this.transactions});

  factory Wallet.fromJson(Map<String, dynamic> json) {
    final wallet = json['wallet'] as Map<String, dynamic>? ?? {};
    return Wallet(
      balance: double.tryParse('${wallet['balance'] ?? 0}') ?? 0,
      transactions: (json['transactions'] as List<dynamic>? ?? [])
          .map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class WalletTransaction {
  final int id;
  final String amount;
  final String kind;
  final String reason;
  final String createdAt;

  const WalletTransaction({
    required this.id,
    required this.amount,
    required this.kind,
    required this.reason,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id'] as int? ?? 0,
        amount: '${json['amount'] ?? 0}',
        kind: json['kind'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
      );
}

class Redemption {
  final int id;
  final String amount;
  final String method;
  final String destination;
  final String status;
  final String userName;
  final String createdAt;

  const Redemption({
    required this.id,
    required this.amount,
    required this.method,
    required this.destination,
    required this.status,
    required this.userName,
    required this.createdAt,
  });

  factory Redemption.fromJson(Map<String, dynamic> json) {
    final user = json['user_detail'] as Map<String, dynamic>?;
    return Redemption(
      id: json['id'] as int? ?? 0,
      amount: '${json['amount'] ?? 0}',
      method: json['method'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      status: json['status'] as String? ?? '',
      userName: user == null
          ? ''
          : (user['full_name'] as String? ?? user['phone'] as String? ?? ''),
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class AppNotification {
  final int id;
  final int? requestId;
  final String title;
  final String body;
  final bool isRead;
  final String createdAt;

  const AppNotification({
    required this.id,
    required this.requestId,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as int? ?? 0,
        requestId: json['request_id'] as int?,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        isRead: json['is_read'] as bool? ?? false,
        createdAt: json['created_at'] as String? ?? '',
      );
}
