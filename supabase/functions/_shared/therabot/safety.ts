// Deterministic safety pre-screen: a FLOOR, not a classifier.
//
// It catches some plain, common phrasings (English and Filipino/Taglish) of
// violence, threats, coercion, stalking, sexual violence, self-harm, suicide
// and immediate danger. It will miss many real situations and will sometimes
// flag harmless figures of speech; both are expected. The model's own safety
// check runs as well, and a flag from EITHER stops normal reflection. Nothing
// here can be overridden by a model saying "not flagged".

import type { SafetyCategory, SafetyCheck } from './schemas.ts';

// Feelings words: "sinaktan mo ang damdamin ko" (you hurt my feelings) is
// not violence, so the Filipino hurt-verbs ignore a feelings word right after.
// ("loob" alone also means "inside", as in "sa loob ng kwarto", so only
// "loob ko" counts as a feelings word.)
const NOT_FEELINGS = String.raw`(?![\s,.;:!-]+([^\s,.;:!]+[\s,.;:!-]+){0,3}(damdamin|puso|feelings|kalooban|loob ko)\b)`;

const RULES: Record<SafetyCategory, RegExp[]> = {
  violence: [
    // "he hit me (at the party)", but not "it hit me how much I missed him"
    /(?<!\b(it|that|this|reality)\s)\bhit(s|ting)?\s+(me|her|him|us)\b(?!\s+(that|how))/,
    // "she beat me (up)", but not "she beat me at chess" / "beat me to it"
    /\b(beat|beats|beating|beaten)\s+(me|her|him|us)\b(?!\s+(at|in|to it))/,
    /\b(punch(ed|es|ing)?|slap(ped|s|ping)?|kick(ed|s|ing)?|shov(ed|es|ing)|push(ed|es|ing)|grab(bed|s|bing))\s+(me|her|him|us)\b(?!\s+(that|how))/,
    // "choked me", but not "I choked up" / "choking back tears"
    /\b(chok(ed|es|ing)|strangl(ed|es|ing))\b(?!\s+(up|back|on))/,
    /\bthrew\s+\w+(\s+\w+)?\s+at\s+me\b/,
    /\bphysically\s+(hurt|attacked|abused)\b/,
    new RegExp(String.raw`\b(sinaktan|sinampal|sinuntok|binugbog|tinadyakan|sinakal|nananakit)\b` + NOT_FEELINGS),
    /\b(pinagbubuhatan|binuhatan|pinagbuhatan) (ako )?ng kamay\b/,
  ],
  threats: [
    /\bthreat(en|ens|ened|ening)\s+to\s+(kill|hurt|harm)\b/,
    // "he said he'd kill me", but not "my mom is gonna kill me" (an idiom)
    /\b(he|she|they|my partner|my (boyfriend|girlfriend|husband|wife))\s*('ll|'d|'s going to|'s gonna| will| would| is going to| is gonna| was going to| said he'?d| said she'?d)\s+(kill|physically hurt)\s+(me|us)\b/,
    /\bthreat(en|ens|ened|ening)\s+(me|my)\b/,
    // the person writing threatening their partner also stops reflection
    /\bi('ll| will| would|'m going to|'m gonna| am going to)\s+(kill|hurt)\s+(him|her|them|you)\b/,
    /\bpapatayin\s+(kita|ako|niya|ka)\b/,
    /\bpapatayin ko\s+(siya|ka|sila)\b/,
    new RegExp(String.raw`\bsasaktan (daw )?(niya|nila) ako\b` + NOT_FEELINGS),
    /\bpinagbantaan\b/,
  ],
  coercion: [
    /\bforc(ed|es|ing)\s+me\s+to\b/,
    /\b(won'?t|doesn'?t|does not|will not)\s+let\s+me\s+(leave|go out|work|see\s+(my\s+)?(friends|family|parents)|talk to\s+(my\s+)?(friends|family|parents))\b/,
    /\b(takes|took|controls|keeps)\s+(all\s+)?my\s+(phone|money|salary|passport|id)\b/,
    /\b(pinilit|pinipilit)\s+(ako|niya ako)\b/,
    /\b(hindi ako pinapalabas|bawal akong lumabas|kinukuha niya ang (pera|sweldo|phone|cellphone) ko)\b/,
  ],
  stalking: [
    // Being stalked, not "ini-stalk ko yung IG niya" (looking at their profile)
    /\b(stalk(s|ed|ing)?\s+me|stalker|stalking me|ini-?stalk niya ako)\b/,
    /\btrack(s|ed|ing)?\s+my\s+(phone|location|car)\b/,
    /\bfollow(s|ed|ing)?\s+me\s+(everywhere|home|to work)\b/,
    /\b(sinusundan|minamanmanan)\s+(ako|niya ako)\b/,
  ],
  sexual_violence: [
    /\b(rape|raped|raping|rapist)\b/,
    /\bsexual(ly)?\s+(assault(ed)?|abus(e|ed))\b/,
    /\bforc(ed|es|ing)\s+me\s+(to\s+have\s+sex|into\s+sex)\b/,
    /\bmolest(ed|s|ing)?\b/,
    /\b(ginahasa|hinalay|pinilit (akong )?makipagtalik)\b/,
  ],
  self_harm: [
    /\b(hurt|hurting|cut|cutting|harm|harming)\s+myself\b/,
    /\bself[-\s]?harm\b/,
    /\b(saktan ang sarili ko|sinasaktan ko ang sarili ko|sugatan ang sarili|naglalaslas|naglaslas|maglaslas|maglalaslas)\b/,
  ],
  suicide: [
    /\bsuicid(e|al)\b/,
    /\b(kill|killing)\s+myself\b/,
    /\bend\s+(it all|my (own )?life)\b/,
    /\b(don'?t|do not)\s+want\s+to\s+(live|be alive)\b/,
    /\bwant\s+to\s+die\b/,
    /\b(magpakamatay|magpapakamatay|gusto ko nang mamatay|wakasan ang buhay ko|sana mamatay na (lang )?ako)\b/,
    /\b(ayoko|ayaw ko)\s+na(ng)?\s+mabuhay\b/,
  ],
  immediate_danger: [
    /\b(i am|i'?m|we are|we'?re)\s+(in danger|not safe)\b/,
    /\b(don'?t|do not|never)\s+feel\s+safe\b/,
    /\b(has|have|got|holding)\s+a\s+(gun|knife|weapon)\b/,
    /\b(nasa panganib|hindi ako ligtas|may baril|may kutsilyo|delikado ako|takot ako sa kanya)\b/,
  ],
};

function normalise(s: string): string {
  return s
    .toLowerCase()
    .replace(/[‘’ʼ]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/\s+/g, ' ');
}

/** Screens all given texts; returns which categories matched (if any). */
export function prescreen(texts: ReadonlyArray<string | null | undefined>): SafetyCheck {
  const joined = normalise(texts.filter((t): t is string => typeof t === 'string').join('\n'));
  const categories: SafetyCategory[] = [];
  for (const [category, patterns] of Object.entries(RULES) as [SafetyCategory, RegExp[]][]) {
    if (patterns.some((p) => p.test(joined))) categories.push(category);
  }
  return {
    flagged: categories.length > 0,
    categories,
    message: categories.length > 0 ? safetyMessage(categories) : '',
  };
}

/**
 * The fixed message for a safety result. Written by people, never by the
 * model: no reconciliation advice, no blame, no romantic suggestions.
 */
export function safetyMessage(categories: readonly SafetyCategory[]): string {
  const parts = [
    'Thank you for trusting Therabot with this. What you shared sounds serious, and your safety matters most, so normal reflection is paused for this session.',
  ];
  // With no known category (e.g. the provider refused the text), show both.
  const unknown = categories.length === 0;
  const harmToSelf = categories.includes('self_harm') || categories.includes('suicide');
  const harmFromOthers = categories.some((c) => c !== 'self_harm' && c !== 'suicide');
  if (unknown || harmFromOthers) {
    parts.push(
      'If you are in immediate danger, call 911. For abuse or violence by a partner, you can call the PNP Women and Children Protection Center at 0919 777 7377.',
    );
  }
  if (unknown || harmToSelf) {
    parts.push(
      'If you are thinking about hurting yourself, you can call the NCMH crisis line at 1553 or 0917 899 8727, any time.',
    );
  }
  parts.push('You do not have to work this out with your partner here, and nothing about this is shared with them.');
  return parts.join(' ');
}

/** Combines two safety results: flagged if either is. */
export function mergeSafety(a: SafetyCheck, b: SafetyCheck): SafetyCheck {
  const categories = [...a.categories];
  for (const c of b.categories) if (!categories.includes(c)) categories.push(c);
  const flagged = a.flagged || b.flagged;
  return { flagged, categories, message: flagged ? safetyMessage(categories) : '' };
}
