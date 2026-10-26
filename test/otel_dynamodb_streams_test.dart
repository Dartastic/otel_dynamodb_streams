// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_dynamodb_streams/otel_dynamodb_streams.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_dynamodb_streams-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('consume records CONSUMER span', () async {
    await tracedDynamodbStreamsConsume<String>(
      tableName: 'Orders',
      shardId: 'shardId-000000000001',
      recordCount: 25,
      eventName: 'MODIFY',
      region: 'us-east-1',
      invoke: () async => 'ok',
    );
    final a = attrsOf(spans.findSpanByName('ddb-streams receive Orders')!);
    expect(a['messaging.system'], 'aws_dynamodb_streams');
    expect(a['aws.dynamodb.streams.shard.id'], 'shardId-000000000001');
    expect(a['messaging.batch.message_count'], 25);
    expect(a['aws.dynamodb.streams.event.name'], 'MODIFY');
  });

  test('suppression skips spans', () async {
    await runWithoutDynamodbStreamsInstrumentationAsync(() async {
      await tracedDynamodbStreamsConsume<String>(
        tableName: 't',
        shardId: 'sh',
        invoke: () async => 'ok',
      );
    });
    expect(spans.findSpansStartingWith('ddb-streams '), isEmpty);
  });
}
