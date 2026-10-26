// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_dynamodb_streams_suppression.dart';

const _tracerName = 'dartastic_otel_libs_dynamodb_streams';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

/// Wraps the handling of one DynamoDB Streams record (or batch of
/// records, when [recordCount] > 1) in a CONSUMER span.
Future<T> tracedDynamodbStreamsConsume<T>({
  required String tableName,
  required String shardId,
  required Future<T> Function() invoke,
  int? recordCount,
  String? eventName,
  String? region,
}) async {
  if (dynamodbStreamsInstrumentationSuppressed()) {
    return invoke();
  }
  final m = <String, Object>{
    'messaging.system': 'aws_dynamodb_streams',
    'messaging.operation': 'receive',
    'messaging.destination.name': tableName,
    'aws.dynamodb.streams.table.name': tableName,
    'aws.dynamodb.streams.shard.id': shardId,
  };
  if (recordCount != null) m['messaging.batch.message_count'] = recordCount;
  if (eventName != null) m['aws.dynamodb.streams.event.name'] = eventName;
  if (region != null) m['cloud.region'] = region;

  final span = _tracer().startSpan(
    'ddb-streams receive $tableName',
    kind: SpanKind.consumer,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    return await invoke();
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
