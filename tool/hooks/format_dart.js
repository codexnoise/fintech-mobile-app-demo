#!/usr/bin/env node
// Hook PostToolUse de Claude Code: formatea con `fvm dart format` cada archivo .dart
// que el agente edita. Automatiza la regla "make format antes de commit".
const { execFileSync } = require('node:child_process');

let input = '';
process.stdin.on('data', (chunk) => (input += chunk));
process.stdin.on('end', () => {
  try {
    const file = JSON.parse(input)?.tool_input?.file_path ?? '';
    if (file.endsWith('.dart')) {
      execFileSync('fvm', ['dart', 'format', file], { stdio: 'ignore' });
    }
  } catch {
    // Nunca bloquear al agente por un fallo de formato.
  }
  process.exit(0);
});
