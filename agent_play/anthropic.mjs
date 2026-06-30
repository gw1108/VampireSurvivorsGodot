// Thin wrapper over the Anthropic SDK for the agent-play loop.
//
// `decide` forces a tool call so every step returns a parseable action drawn from the
// current `available_actions` (never raw-string matching), plus any findings.
// `summarize` produces the final free-text assessment for the run report.
import Anthropic from '@anthropic-ai/sdk';
import { config } from './config.mjs';

let _client = null;
function client() {
  if (!config.apiKey) {
    throw new Error('ANTHROPIC_API_KEY is not set. Add it to .env (see .env.example).');
  }
  if (!_client) _client = new Anthropic({ apiKey: config.apiKey });
  return _client;
}

function imageBlocks(images) {
  // images: [{ label, b64 }]
  const blocks = [];
  for (const img of images || []) {
    if (!img || !img.b64) continue;
    if (img.label) blocks.push({ type: 'text', text: img.label });
    blocks.push({
      type: 'image',
      source: { type: 'base64', media_type: 'image/png', data: img.b64 },
    });
  }
  return blocks;
}

const DECIDE_TOOL = {
  name: 'decide',
  description:
    'Report observations and choose the next action. Always call this exactly once.',
  input_schema: {
    type: 'object',
    properties: {
      action: {
        type: 'string',
        description:
          'The single action to take this step. Must be one of available_actions, or "noop" to do nothing.',
      },
      reason: { type: 'string', description: 'One short sentence on why.' },
      findings: {
        type: 'array',
        description:
          'Observations, bugs, or critiques noticed THIS step. May be empty. Be specific and evidence-based.',
        items: {
          type: 'object',
          properties: {
            severity: {
              type: 'string',
              enum: ['info', 'low', 'medium', 'high', 'critical'],
            },
            title: { type: 'string' },
            detail: { type: 'string' },
          },
          required: ['severity', 'title'],
        },
      },
    },
    required: ['action'],
  },
};

export async function decide({ system, state, events, audio, availableActions, images }) {
  const actions = availableActions && availableActions.length ? availableActions : [];
  const allowed = [...actions, 'noop'];

  const content = [...imageBlocks(images)];
  let text =
    `AgentState (current):\n\`\`\`json\n${JSON.stringify(state)}\n\`\`\`\n\n` +
    `New events since last step:\n\`\`\`json\n${JSON.stringify(events || [])}\n\`\`\`\n\n`;
  if (audio && audio.length) {
    text += `Audio playback attempts (from the WebAudio probe) since last step:\n\`\`\`json\n${JSON.stringify(audio)}\n\`\`\`\n\n`;
  }
  text +=
    `Legal actions this step: ${JSON.stringify(allowed)}.\n` +
    `Call \`decide\` once: pick one action from that list and report any findings.`;
  content.push({ type: 'text', text });

  const msg = await client().messages.create({
    model: config.model,
    max_tokens: 1024,
    system,
    tools: [DECIDE_TOOL],
    tool_choice: { type: 'tool', name: 'decide' },
    messages: [{ role: 'user', content }],
  });

  const use = msg.content.find((c) => c.type === 'tool_use');
  const input = (use && use.input) || {};
  let action = typeof input.action === 'string' ? input.action : 'noop';
  if (!allowed.includes(action)) action = 'noop'; // guard against off-list actions
  return {
    action,
    reason: input.reason || '',
    findings: Array.isArray(input.findings) ? input.findings : [],
    usage: msg.usage || null,
  };
}

export async function summarize({ system, transcript }) {
  const msg = await client().messages.create({
    model: config.model,
    max_tokens: 2048,
    system:
      system +
      '\n\n---\nThe play session is over. Write your FINAL REPORT in Markdown based on the session log below. ' +
      'Follow the output format described in your role above (scorecard / findings / coverage matrix as applicable). ' +
      'Be concrete and cite specific steps/events.',
    messages: [{ role: 'user', content: [{ type: 'text', text: transcript }] }],
  });
  return msg.content
    .filter((c) => c.type === 'text')
    .map((c) => c.text)
    .join('\n')
    .trim();
}
