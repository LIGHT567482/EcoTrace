import 'package:flutter_test/flutter_test.dart';

import 'package:ecotrace/core/models.dart';
import 'package:ecotrace/core/widgets.dart';

void main() {
  test('formatUGX groups thousands', () {
    expect(formatUGX(12000), 'UGX 12,000');
    expect(formatUGX('6000'), 'UGX 6,000');
    expect(formatUGX(null), 'UGX 0');
  });

  test('CollectionRequest parses a typical payload', () {
    final json = {
      'id': 7,
      'reference': 'ET-ABCD1234',
      'request_type': 'PICKUP',
      'status': 'PENDING',
      'status_label': 'Pending',
      'items': [
        {
          'id': 1,
          'item_type': 3,
          'type_name': 'Smartphone',
          'category_name': 'Phones',
          'quantity': 2,
          'condition': 'BROKEN',
          'notes': '',
          'reward_ugx': '6000.00',
        }
      ],
      'item_count': 2,
      'pickup_address': 'Plot 1, Kansanga',
      'reward_credited': false,
      'consumer_detail': {'id': 1, 'phone': '+256700000013', 'full_name': 'Mary'},
      'events': [
        {'id': 1, 'status': 'PENDING', 'note': 'created', 'created_at': '2026-10-26T09:00:00Z'}
      ],
      'certificate': null,
      'created_at': '2026-10-26T09:00:00Z',
    };
    final req = CollectionRequest.fromJson(json);
    expect(req.reference, 'ET-ABCD1234');
    expect(req.itemCount, 2);
    expect(req.items.first.typeName, 'Smartphone');
    expect(req.consumerName, 'Mary');
    expect(req.events, hasLength(1));
    expect(req.certificate, isNull);
  });
}
