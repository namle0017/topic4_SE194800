const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const http = require('node:http');
const { after, before, test } = require('node:test');
const { createAuthService } = require('../src/auth_service');
const { InMemoryAuthStore } = require('../src/auth_store');
const { issueToken, verifyToken } = require('../src/token');

const port = 18000 + (process.pid % 1000);
const baseUrl = `http://127.0.0.1:${port}`;
let serverProcess;

async function startBackend(targetPort, extraEnv = {}) {
  const child = spawn(process.execPath, ['server.js'], {
    cwd: __dirname + '/..',
    env: {
      ...process.env,
      PORT: String(targetPort),
      JWT_SECRET: 'test-only-secret-with-sufficient-length',
      ...extraEnv,
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  await new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error('Backend did not start within 5 seconds.')),
      5000,
    );
    child.once('error', reject);
    child.once('exit', (code) => {
      if (code !== null && code !== 0) {
        reject(new Error(`Backend exited with code ${code}.`));
      }
    });
    child.stdout.on('data', (chunk) => {
      if (chunk.toString().includes(`http://localhost:${targetPort}`)) {
        clearTimeout(timer);
        resolve();
      }
    });
  });
  return child;
}

async function requestAt(targetBaseUrl, path, options = {}) {
  const { method = 'GET', body, headers = {} } = options;
  const response = await fetch(`${targetBaseUrl}${path}`, {
    method,
    headers: body === undefined
      ? headers
      : { 'Content-Type': 'application/json', ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  return {
    status: response.status,
    body: text ? JSON.parse(text) : null,
  };
}

async function request(path, { method = 'GET', body, headers = {} } = {}) {
  return requestAt(baseUrl, path, { method, body, headers });
}

before(async () => {
  serverProcess = await startBackend(port, { DEV_OTP: '123456' });
});

after(() => {
  serverProcess?.kill();
});

test('register normalizes email and never exposes authentication secrets', async () => {
  const registered = await request('/api/auth/register', {
    method: 'POST',
    body: {
      name: 'Demo User',
      email: 'Demo@Test.com',
      password: '123456',
    },
  });

  assert.equal(registered.status, 202);
  assert.equal(registered.body.success, true);
  assert.equal(typeof registered.body.result.verificationId, 'string');
  assert.equal(registered.body.result.cooldownSeconds, 60);
  assert.equal(JSON.stringify(registered.body).includes('123456'), false);

  const duplicate = await request('/api/auth/register', {
    method: 'POST',
    body: {
      name: 'Another User',
      email: 'demo@test.com',
      password: 'abcdef',
    },
  });

  assert.equal(duplicate.status, 409);
});

function createServiceHarness() {
  let now = 1_000_000;
  const sentCodes = [];
  const store = new InMemoryAuthStore();
  const service = createAuthService({
    store,
    secret: 'test-only-secret-with-sufficient-length',
    clock: () => now,
    generateOtp: () => '123456',
    generateId: () => `verification-${sentCodes.length + 1}`,
    sendOtp: async ({ email, otp }) => sentCodes.push({ email, otp }),
  });
  return {
    service,
    store,
    sentCodes,
    advance(milliseconds) {
      now += milliseconds;
    },
  };
}

test('Google-created accounts reject password login without crashing', async () => {
  const harness = createServiceHarness();
  await harness.service.loginWithGoogle({
    email: 'google-only@test.com',
    name: 'Google Only',
  });

  await assert.rejects(
    harness.service.login({
      email: 'google-only@test.com',
      password: '123456',
    }),
    (error) => error.status === 401,
  );
});

test('OTP verification activates an account before login is allowed', async () => {
  const harness = createServiceHarness();
  const registration = await harness.service.register({
    name: 'Flow User',
    email: 'flow@test.com',
    password: '123456',
  });

  await assert.rejects(
    harness.service.login({ email: 'flow@test.com', password: '123456' }),
    (error) => error.status === 403,
  );
  await assert.rejects(
    harness.service.verifyEmail({
      verificationId: registration.verificationId,
      otp: '000000',
    }),
    (error) => error.status === 400,
  );

  await harness.service.verifyEmail({
    verificationId: registration.verificationId,
    otp: '123456',
  });
  const login = await harness.service.login({
    email: 'FLOW@test.com',
    password: '123456',
  });

  assert.equal(login.email, 'flow@test.com');
  assert.equal(login.provider, 'password');
  assert.equal(typeof login.accessToken, 'string');
  assert.equal(login.accessToken.split('.').length, 3);
});

test('OTP rejects expired codes and locks after five wrong attempts', async () => {
  const expired = createServiceHarness();
  const expiredRegistration = await expired.service.register({
    name: 'Expired User',
    email: 'expired@test.com',
    password: '123456',
  });
  expired.advance(10 * 60 * 1000 + 1);
  await assert.rejects(
    expired.service.verifyEmail({
      verificationId: expiredRegistration.verificationId,
      otp: '123456',
    }),
    (error) => error.status === 410,
  );

  const locked = createServiceHarness();
  const lockedRegistration = await locked.service.register({
    name: 'Locked User',
    email: 'locked@test.com',
    password: '123456',
  });
  for (let attempt = 1; attempt <= 4; attempt += 1) {
    await assert.rejects(
      locked.service.verifyEmail({
        verificationId: lockedRegistration.verificationId,
        otp: '000000',
      }),
      (error) => error.status === 400,
    );
  }
  await assert.rejects(
    locked.service.verifyEmail({
      verificationId: lockedRegistration.verificationId,
      otp: '000000',
    }),
    (error) => error.status === 429,
  );
  await assert.rejects(
    locked.service.verifyEmail({
      verificationId: lockedRegistration.verificationId,
      otp: '123456',
    }),
    (error) => error.status === 429,
  );
});

test('resend enforces cooldown and replaces the OTP', async () => {
  const harness = createServiceHarness();
  const registration = await harness.service.register({
    name: 'Resend User',
    email: 'resend@test.com',
    password: '123456',
  });

  await assert.rejects(
    harness.service.resendEmailVerification({
      verificationId: registration.verificationId,
      email: 'resend@test.com',
    }),
    (error) => error.status === 429,
  );

  harness.advance(60 * 1000);
  const resent = await harness.service.resendEmailVerification({
    verificationId: registration.verificationId,
    email: 'resend@test.com',
  });

  assert.equal(resent.verificationId, registration.verificationId);
  assert.equal(resent.cooldownSeconds, 60);
  assert.equal(harness.sentCodes.length, 2);
});

test('login rejects a wrong password after activation', async () => {
  const harness = createServiceHarness();
  const registration = await harness.service.register({
    name: 'Password User',
    email: 'password@test.com',
    password: '123456',
  });
  await harness.service.verifyEmail({
    verificationId: registration.verificationId,
    otp: '123456',
  });

  await assert.rejects(
    harness.service.login({
      email: 'password@test.com',
      password: 'wrong-password',
    }),
    (error) => error.status === 401,
  );
});

test('HTTP auth flow verifies email, logs in, and restores the session', async () => {
  const registered = await request('/api/auth/register', {
    method: 'POST',
    body: {
      name: 'API User',
      email: 'api@test.com',
      password: '123456',
    },
  });

  const verified = await request('/api/auth/email-verification/verify', {
    method: 'POST',
    body: {
      verificationId: registered.body.result.verificationId,
      otp: '123456',
    },
  });
  assert.equal(verified.status, 200);

  const loggedIn = await request('/api/auth/login', {
    method: 'POST',
    body: { email: 'api@test.com', password: '123456' },
  });
  assert.equal(loggedIn.status, 200);
  assert.equal(loggedIn.body.result.provider, 'password');

  const restored = await request('/api/me', {
    headers: {
      Authorization: `Bearer ${loggedIn.body.result.accessToken}`,
    },
  });
  assert.equal(restored.status, 200);
  assert.deepEqual(restored.body.result, {
    name: 'API User',
    email: 'api@test.com',
    provider: 'password',
  });
});

test('application tokens reject tampering and expiration', () => {
  const secret = 'test-only-secret-with-sufficient-length';
  const issuedAt = 1_000_000;
  const token = issueToken(
    { sub: 'token@test.com', email: 'token@test.com' },
    secret,
    issuedAt,
  );

  assert.equal(verifyToken(token, secret, issuedAt).email, 'token@test.com');
  assert.equal(verifyToken(`${token}x`, secret, issuedAt), null);
  assert.equal(verifyToken(token, secret, issuedAt + 60 * 60 * 1000), null);
});

test('HTTP server rejects malformed JSON and oversized bodies without crashing', async () => {
  const malformedResponse = await fetch(`${baseUrl}/api/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: '{not-json',
  });
  assert.equal(malformedResponse.status, 400);

  const oversizedResponse = await fetch(`${baseUrl}/api/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      name: 'x'.repeat(70 * 1024),
      email: 'large@test.com',
      password: '123456',
    }),
  });
  assert.equal(oversizedResponse.status, 413);

  const nextRequest = await request('/not-found');
  assert.equal(nextRequest.status, 404);
});

test('HTTP session restoration rejects an invalid bearer token', async () => {
  const response = await request('/api/me', {
    headers: { Authorization: 'Bearer invalid-token' },
  });

  assert.equal(response.status, 401);
});

test('sender configuration is required outside explicit DEV_OTP mode', async () => {
  const targetPort = port + 1;
  const child = await startBackend(targetPort, {
    DEV_OTP: '',
    SMTP_HOST: '',
    SMTP_USER: '',
    SMTP_PASS: '',
  });
  try {
    const response = await requestAt(
      `http://127.0.0.1:${targetPort}`,
      '/api/auth/register',
      {
        method: 'POST',
        body: {
          name: 'No Sender',
          email: 'no-sender@test.com',
          password: '123456',
        },
      },
    );
    assert.equal(response.status, 503);
    assert.equal(response.body.success, false);
  } finally {
    child.kill();
  }
});

test('Google token is verified by Supabase before an app token is issued', async () => {
  const fakeSupabase = http.createServer((request, response) => {
    if (request.headers.authorization === 'Bearer malformed-response') {
      response.writeHead(200, { 'Content-Type': 'text/plain' });
      response.end('not-json');
      return;
    }
    if (
      request.url === '/auth/v1/user' &&
      request.headers.authorization === 'Bearer valid-supabase-token' &&
      request.headers.apikey === 'test-publishable-key'
    ) {
      response.writeHead(200, { 'Content-Type': 'application/json' });
      response.end(
        JSON.stringify({
          id: 'google-user-id',
          email: 'google@test.com',
          user_metadata: { full_name: 'Google User' },
        }),
      );
      return;
    }
    response.writeHead(401, { 'Content-Type': 'application/json' });
    response.end(JSON.stringify({ message: 'Invalid token' }));
  });
  await new Promise((resolve) => fakeSupabase.listen(0, '127.0.0.1', resolve));
  const supabasePort = fakeSupabase.address().port;
  const targetPort = port + 2;
  const child = await startBackend(targetPort, {
    DEV_OTP: '123456',
    SUPABASE_URL: `http://127.0.0.1:${supabasePort}`,
    SUPABASE_PUBLISHABLE_KEY: 'test-publishable-key',
  });

  try {
    const googleLogin = await requestAt(
      `http://127.0.0.1:${targetPort}`,
      '/api/auth/google',
      {
        method: 'POST',
        body: { accessToken: 'valid-supabase-token' },
      },
    );
    assert.equal(googleLogin.status, 200);
    assert.equal(googleLogin.body.result.email, 'google@test.com');
    assert.equal(googleLogin.body.result.provider, 'google');
    assert.equal(typeof googleLogin.body.result.accessToken, 'string');

    const repeated = await requestAt(
      `http://127.0.0.1:${targetPort}`,
      '/api/auth/google',
      {
        method: 'POST',
        body: { accessToken: 'valid-supabase-token' },
      },
    );
    assert.equal(repeated.status, 200);

    const invalid = await requestAt(
      `http://127.0.0.1:${targetPort}`,
      '/api/auth/google',
      {
        method: 'POST',
        body: { accessToken: 'invalid-supabase-token' },
      },
    );
    assert.equal(invalid.status, 401);

    const malformed = await requestAt(
      `http://127.0.0.1:${targetPort}`,
      '/api/auth/google',
      {
        method: 'POST',
        body: { accessToken: 'malformed-response' },
      },
    );
    assert.equal(malformed.status, 502);
  } finally {
    child.kill();
    await new Promise((resolve) => fakeSupabase.close(resolve));
  }
});

test('Google verification reports an unavailable Supabase service', async () => {
  const targetPort = port + 3;
  const child = await startBackend(targetPort, {
    DEV_OTP: '123456',
    SUPABASE_URL: 'http://127.0.0.1:9',
    SUPABASE_PUBLISHABLE_KEY: 'test-publishable-key',
  });
  try {
    const response = await requestAt(
      `http://127.0.0.1:${targetPort}`,
      '/api/auth/google',
      {
        method: 'POST',
        body: { accessToken: 'network-error-token' },
      },
    );
    assert.equal(response.status, 502);
  } finally {
    child.kill();
  }
});
