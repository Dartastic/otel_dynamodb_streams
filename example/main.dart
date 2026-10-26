// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_dynamodb_streams/otel_dynamodb_streams.dart';

/// Traces Dynamodb Streams calls with OpenTelemetry.
///
/// `otel_dynamodb_streams` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Dynamodb Streams call in
/// [tracedDynamodbStreamsConsume]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'dynamodb-streams-example');

  // Wraps the handling of one DynamoDB Streams record (or batch of records, when [recordCount] > 1) in a CONSUMER span.
  final dynamodbStreamsConsumeId = await tracedDynamodbStreamsConsume<String>(
    tableName: 'orders',
    shardId: 'shard_8f3a2c',
    recordCount: 3,
    eventName: 'order.created',
    region: 'us-east-1',
    invoke: () async {
      // Make the Dynamodb Streams call here, then report what it returned.
      return 'dynamodb_streams_8f3a2c';
    },
  );
  OTelLog.info(
      'tracedDynamodbStreamsConsume returned $dynamodbStreamsConsumeId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutDynamodbStreamsInstrumentationAsync.
  await runWithoutDynamodbStreamsInstrumentationAsync(
    () => tracedDynamodbStreamsConsume<String>(
      tableName: 'orders',
      shardId: 'shard_8f3a2c',
      recordCount: 3,
      eventName: 'order.created',
      region: 'us-east-1',
      invoke: () async {
        return 'dynamodb_streams_8f3a2c';
      },
    ),
  );

  await OTel.shutdown();
}
