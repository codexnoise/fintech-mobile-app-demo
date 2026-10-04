import { createApp } from '../src/http/app';
import type { Deps } from '../src/ports';
import {
  FakeContextTokens,
  FakeIdentity,
  FixedClock,
  MemoryDevices,
  MemoryExperienceStore,
  MemoryFlags,
  MemoryStore,
  RecordingNotifier,
  SequentialIds,
} from '../src/adapters/memory';

import { NOW } from './fixtures';

export { NOW };

export function makeTestApp(overrides: Partial<Deps> = {}) {
  const store = new MemoryStore();
  const experiences = new MemoryExperienceStore();
  const flags = new MemoryFlags();
  const devices = new MemoryDevices();
  const notifier = new RecordingNotifier();
  const deps: Deps = {
    users: store,
    ledger: store,
    experiences,
    flags,
    devices,
    notifier,
    identity: new FakeIdentity(),
    contextTokens: new FakeContextTokens(),
    assistantModel: null,
    clock: new FixedClock(NOW),
    ids: new SequentialIds(),
    config: { appCheckEnforced: true, adminApiKey: 'admin-secret', microAppOrigins: ['https://travel.example.com'], assistantTimeoutMs: 200 },
    ...overrides,
  };
  return { app: createApp(deps), deps, store, experiences, flags, devices, notifier };
}

export const authHeaders = (uid = 'user-1') => ({
  Authorization: `Bearer valid:${uid}`,
  'X-Firebase-AppCheck': 'appcheck-ok',
});

export const onboardingPayload = {
  firstName: 'Diego',
  birthYear: 2001,
  occupation: 'employee',
  incomeRange: 'medium',
} as const;
