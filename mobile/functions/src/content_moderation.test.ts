import test from 'node:test';
import assert from 'node:assert/strict';
import { moderationRejection } from './content_moderation';

test('allows a normal friendship-first message', () => {
  assert.equal(moderationRejection('Want to check out the farmers market this weekend?'), null);
});

test('rejects harmful, explicit, and contact-sharing messages', () => {
  assert.notEqual(moderationRejection('I will kill you'), null);
  assert.notEqual(moderationRejection('Send me nudes'), null);
  assert.notEqual(moderationRejection('Text me at 212-555-0199'), null);
  assert.notEqual(moderationRejection('Email me at hello@example.com'), null);
});
