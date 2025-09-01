#!/usr/bin/env node

/**
 * Secure wrapper for release notes generation
 * This prevents connection strings from appearing in npm command logs
 */

import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';
import fs from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Resolve tsx CLI JS entry via package.json bin field and run it with Node to avoid .cmd issues on Windows
const require = createRequire(import.meta.url);

function resolveTsxCliFromPkg(startDir) {
  try {
    const pkgPath = require.resolve('tsx/package.json', { paths: [startDir] });
    const pkgDir = path.dirname(pkgPath);
    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
    let binRel = null;
    if (typeof pkg.bin === 'string') {
      binRel = pkg.bin;
    } else if (pkg.bin && pkg.bin.tsx) {
      binRel = pkg.bin.tsx;
    } else {
      binRel = 'dist/cli.js';
    }
    const cliPath = path.resolve(pkgDir, binRel);
    if (fs.existsSync(cliPath)) {
      return cliPath;
    }
  } catch {
    // ignore
  }
  return null;
}

const tsxCliLocal = resolveTsxCliFromPkg(__dirname);
const tsxCliRoot = resolveTsxCliFromPkg(path.join(__dirname, '..', '..'));
const tsxCli = tsxCliLocal || tsxCliRoot;

if (!tsxCli) {
  console.error('Could not locate tsx CLI.');
  console.error('Try installing dependencies:');
  console.error('  cd tools/release-notes');
  console.error('  npm ci');
  process.exit(1);
}

const child = spawn(process.execPath, [tsxCli, 'generate-release-notes.ts', ...process.argv.slice(2)], {
  cwd: __dirname,
  stdio: ['inherit', 'pipe', 'pipe'],
  env: {
    ...process.env,
    npm_config_silent: 'true',
    npm_config_loglevel: 'error'
  }
});

let stdout = '';
let stderr = '';

child.stdout.on('data', (data) => {
  const output = data.toString();
  stdout += output;
  // Filter out any potential connection string leaks before logging
  const safeOutput = output
    .replace(/password=([^;\s]+)/gi, 'password=***')
    .replace(/pwd=([^;\s]+)/gi, 'pwd=***')
    .replace(/user id=([^;\s]+)/gi, 'user id=***')
    .replace(/Server=([^;\s]+)/gi, 'Server=***');
  
  process.stdout.write(safeOutput);
});

child.stderr.on('data', (data) => {
  const output = data.toString();
  stderr += output;
  // Filter out any potential connection string leaks before logging
  const safeOutput = output
    .replace(/password=([^;\s]+)/gi, 'password=***')
    .replace(/pwd=([^;\s]+)/gi, 'pwd=***')
    .replace(/user id=([^;\s]+)/gi, 'user id=***')
    .replace(/Server=([^;\s]+)/gi, 'Server=***');
  
  process.stderr.write(safeOutput);
});

child.on('close', (code) => {
  if (code !== 0) {
    console.error(`\nRelease notes generation failed with exit code ${code}`);
    console.error('   Check your database connection and credentials.');
  }
  process.exit(code);
});

child.on('error', (error) => {
  console.error('Failed to start release notes generator:', error.message);
  process.exit(1);
});
