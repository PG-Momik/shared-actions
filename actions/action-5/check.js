const fs = require('node:fs');

function section(body, title) {
  const lines = body.split(/\r?\n/);
  const start = lines.findIndex(line => line.trim().toLowerCase() === `## ${title.toLowerCase()}`);
  if (start === -1) return '';
  const next = lines.findIndex((line, i) => i > start && /^##\s+/.test(line));
  return lines.slice(start + 1, next === -1 ? undefined : next).join('\n').split(/^---\s*$/m)[0].trim();
}

function checkTitle(title) {
  if (/^(story|bug|task|hotfix)\(XP-[0-9]+\): [^\n]{1,72}$/.test(title)) return [];
  return ['PR title needs a supported type, ticket ID, and short description, e.g. story(XP-12): add login page'];
}

function checkBody(body) {
  const findings = [];
  if (/<!--|-->/.test(body)) findings.push('PR body contains an HTML comment.');
  if (/\b(?:low risk|well tested|should be safe|no impact expected|tests pass)\b/i.test(body)) {
    findings.push('PR body contains a banned risk claim.');
  }
  const summary = section(body, 'Summary');
  const risk = section(body, 'Risk');
  const tier = risk.match(/^(Low|Medium|High)\b/i)?.[1]?.toLowerCase();
  const bullets = summary.split(/\r?\n/).filter(line => /^\s*[-*]\s+\S/.test(line)).length;
  if (bullets < (tier === 'low' ? 1 : 2) || bullets > 5) findings.push('Summary needs 2-5 nonempty bullets, or one for Low risk.');
  if (!tier || risk.replace(/^(Low|Medium|High)\b/i, '').trim().length < 12) findings.push('Risk needs a tier and a concrete consequence.');
  return findings;
}

function main() {
  const event = JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8'));
  const pr = event.pull_request;
  if (!pr) return console.log('Not a pull request event, nothing to check.');
  const isDependabot = pr.user?.login === 'dependabot[bot]' && pr.user?.type === 'Bot';
  const findings = [...(isDependabot ? [] : checkTitle(pr.title || '')), ...checkBody(pr.body || '')];
  for (const f of findings) console.log(`::error::${f}`);
  if (findings.length) process.exit(1);
  console.log('PR checklist passed.');
}

if (require.main === module) main();
module.exports = { checkTitle, checkBody };
