const emailPattern = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i;
const urlPattern = /\b(?:https?:\/\/|www\.)\S+/i;
const phonePattern = /(?:\+?\d[\s().-]*){8,}/;
const controlCharacterPattern = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/;
const abusiveTerms = new Set([
  'cazzo',
  'coglione',
  'coglioni',
  'merda',
  'stronzo',
  'stronza',
  'vaffanculo',
]);

export function moderateSuggestion({ title, description }) {
  const content = `${title}\n${description}`;
  if (controlCharacterPattern.test(content)) {
    return rejected('unsafe_characters');
  }
  if (urlPattern.test(content)) return rejected('external_link');
  if (emailPattern.test(content) || phonePattern.test(content)) {
    return rejected('personal_data');
  }

  const words = normalizeForModeration(content).match(/[a-z]+/g) ?? [];
  if (words.some((word) => abusiveTerms.has(word))) {
    return rejected('abusive_language');
  }
  return { allowed: true, reason: null };
}

function normalizeForModeration(value) {
  return value
    .normalize('NFKD')
    .replaceAll(/[\u0300-\u036f]/g, '')
    .toLowerCase();
}

function rejected(reason) {
  return { allowed: false, reason };
}
