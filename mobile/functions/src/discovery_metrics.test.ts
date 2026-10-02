import assert from 'node:assert/strict';
import test from 'node:test';
import { hasNewSafetyEntry, metricDocumentId } from './discovery_metrics';

test('metrics are grouped by UTC day and ranking version', () => {
  assert.equal(metricDocumentId('v1', new Date('2026-10-01T15:00:00Z')), '2026-10-01_v1');
  assert.equal(metricDocumentId('experiment/a', new Date('2026-10-01T15:00:00Z')), '2026-10-01_experiment_a');
});

test('safety telemetry counts only newly-added choices', () => {
  assert.equal(hasNewSafetyEntry(['wave-1'], ['wave-1']), false);
  assert.equal(hasNewSafetyEntry(['wave-1'], ['wave-1', 'wave-2']), true);
  assert.equal(hasNewSafetyEntry(['member-a'], []), false);
});
