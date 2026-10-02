const blockedPatterns = [
  /\b(?:kill yourself|kys|i(?:'m| am) going to kill|i will kill|shoot you|rape you)\b/i,
  /\b(?:send (?:me )?nudes?|explicit photos?|sexual services?)\b/i,
];

const emailPattern = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i;
const phonePattern = /(?:\+?\d[\d(). -]{7,}\d)/;

/// Applies a conservative safety screen before a message is stored. This is a
/// guardrail, not a substitute for member reports and human review.
export function moderationRejection(text: string): string | null {
  if (blockedPatterns.some((pattern) => pattern.test(text))) {
    return 'This message may violate Commons safety guidelines.';
  }
  if (emailPattern.test(text) || phonePattern.test(text)) {
    return 'Please do not share contact details in Commons messages.';
  }
  return null;
}
