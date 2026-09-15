import { execFileSync } from 'node:child_process';
import { cp, mkdir, rm } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const workerDir = resolve(fileURLToPath(new URL('..', import.meta.url)));
const flutterDir = resolve(workerDir, '../frontEnd/leva_ai');
const source = resolve(flutterDir, 'build/web');
const target = resolve(workerDir, 'public');

execFileSync('flutter', ['build', 'web', '--release'], { cwd: flutterDir, stdio: 'inherit', shell: process.platform === 'win32' });
await rm(target, { recursive: true, force: true });
await mkdir(target, { recursive: true });
await cp(source, target, { recursive: true });
