const crypto = require('node:crypto');
const { issueToken, verifyToken } = require('./token');

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const OTP_TTL_MS = 10 * 60 * 1000;
const OTP_COOLDOWN_MS = 60 * 1000;

class AuthError extends Error {
  constructor(status, message) {
    super(message);
    this.name = 'AuthError';
    this.status = status;
  }
}

function hashSecret(value, salt) {
  return crypto.scryptSync(value, salt, 32).toString('hex');
}

function normalizeEmail(value) {
  return String(value ?? '').trim().toLowerCase();
}

function secretsMatch(left, right) {
  const leftBuffer = Buffer.from(left, 'hex');
  const rightBuffer = Buffer.from(right, 'hex');
  return (
    leftBuffer.length === rightBuffer.length &&
    crypto.timingSafeEqual(leftBuffer, rightBuffer)
  );
}

function createAuthService({
  store,
  secret,
  clock = Date.now,
  generateOtp,
  sendOtp,
  generateId = crypto.randomUUID,
}) {
  if (!store || !secret || !generateOtp || !sendOtp) {
    throw new Error('Auth service dependencies are required.');
  }

  async function register({ name, email, password }) {
    const normalizedName = String(name ?? '').trim();
    const normalizedEmail = normalizeEmail(email);
    const rawPassword = String(password ?? '');

    if (!normalizedName || !EMAIL_PATTERN.test(normalizedEmail)) {
      throw new AuthError(400, 'Name and a valid email are required.');
    }
    if (rawPassword.length < 6) {
      throw new AuthError(400, 'Password must contain at least 6 characters.');
    }
    if (store.findUserByEmail(normalizedEmail)) {
      throw new AuthError(409, 'Email already exists.');
    }

    const passwordSalt = crypto.randomBytes(16).toString('hex');
    const otpSalt = crypto.randomBytes(16).toString('hex');
    const otp = String(generateOtp());
    const now = clock();
    const verificationId = generateId();
    const user = {
      name: normalizedName,
      email: normalizedEmail,
      provider: 'password',
      active: false,
      passwordSalt,
      passwordHash: hashSecret(rawPassword, passwordSalt),
    };
    const verification = {
      id: verificationId,
      email: normalizedEmail,
      otpSalt,
      otpHash: hashSecret(otp, otpSalt),
      expiresAt: now + OTP_TTL_MS,
      resendAvailableAt: now + OTP_COOLDOWN_MS,
      attempts: 0,
    };

    store.saveUser(user);
    store.saveVerification(verification);
    try {
      await sendOtp({ email: normalizedEmail, otp });
    } catch (error) {
      store.deleteUser(normalizedEmail);
      store.deleteVerification(verificationId);
      throw error;
    }

    return {
      verificationId,
      email: normalizedEmail,
      cooldownSeconds: OTP_COOLDOWN_MS / 1000,
    };
  }

  async function verifyEmail({ verificationId, otp }) {
    const verification = store.findVerificationById(String(verificationId ?? ''));
    if (!verification) {
      throw new AuthError(404, 'Verification request was not found.');
    }
    if (verification.attempts >= 5) {
      throw new AuthError(429, 'Too many incorrect verification attempts.');
    }
    if (verification.expiresAt < clock()) {
      throw new AuthError(410, 'Verification code has expired.');
    }

    verification.attempts += 1;
    const candidateHash = hashSecret(String(otp ?? ''), verification.otpSalt);
    if (!secretsMatch(candidateHash, verification.otpHash)) {
      if (verification.attempts >= 5) {
        throw new AuthError(429, 'Too many incorrect verification attempts.');
      }
      throw new AuthError(400, 'Verification code is incorrect.');
    }

    const user = store.findUserByEmail(verification.email);
    if (!user) {
      throw new AuthError(404, 'Account was not found.');
    }
    user.active = true;
    store.saveUser(user);
    store.deleteVerification(verification.id);
  }

  async function resendEmailVerification({ verificationId, email }) {
    const verification = store.findVerificationById(String(verificationId ?? ''));
    const normalizedEmail = normalizeEmail(email);
    if (!verification || verification.email !== normalizedEmail) {
      throw new AuthError(404, 'Verification request was not found.');
    }
    const now = clock();
    if (verification.resendAvailableAt > now) {
      throw new AuthError(429, 'Please wait before requesting another code.');
    }

    const otp = String(generateOtp());
    const otpSalt = crypto.randomBytes(16).toString('hex');
    const updated = {
      ...verification,
      otpSalt,
      otpHash: hashSecret(otp, otpSalt),
      expiresAt: now + OTP_TTL_MS,
      resendAvailableAt: now + OTP_COOLDOWN_MS,
      attempts: 0,
    };
    await sendOtp({ email: normalizedEmail, otp });
    store.saveVerification(updated);
    return {
      verificationId: updated.id,
      email: normalizedEmail,
      cooldownSeconds: OTP_COOLDOWN_MS / 1000,
    };
  }

  async function login({ email, password }) {
    const normalizedEmail = normalizeEmail(email);
    const user = store.findUserByEmail(normalizedEmail);
    const candidateHash = user?.passwordSalt && user?.passwordHash
      ? hashSecret(String(password ?? ''), user.passwordSalt)
      : null;
    if (!user || !candidateHash || !secretsMatch(candidateHash, user.passwordHash)) {
      throw new AuthError(401, 'Email or password is incorrect.');
    }
    if (!user.active) {
      throw new AuthError(403, 'Verify your email before signing in.');
    }
    return {
      accessToken: issueToken(
        {
          sub: user.email,
          name: user.name,
          email: user.email,
          provider: user.provider,
        },
        secret,
        clock(),
      ),
      name: user.name,
      email: user.email,
      provider: user.provider,
    };
  }

  async function loginWithGoogle({ email, name }) {
    const normalizedEmail = normalizeEmail(email);
    if (!EMAIL_PATTERN.test(normalizedEmail)) {
      throw new AuthError(400, 'Google account does not contain a valid email.');
    }
    const existing = store.findUserByEmail(normalizedEmail);
    const user = {
      ...(existing ?? {}),
      name: String(name ?? '').trim() || normalizedEmail.split('@')[0],
      email: normalizedEmail,
      provider: 'google',
      active: true,
    };
    store.saveUser(user);
    return {
      accessToken: issueToken(
        {
          sub: user.email,
          name: user.name,
          email: user.email,
          provider: user.provider,
        },
        secret,
        clock(),
      ),
      name: user.name,
      email: user.email,
      provider: user.provider,
    };
  }

  async function restoreSession(token) {
    const payload = verifyToken(token, secret, clock());
    const user = payload?.sub ? store.findUserByEmail(payload.sub) : null;
    if (!user || !user.active) {
      throw new AuthError(401, 'Authentication token is invalid or expired.');
    }
    return {
      name: user.name,
      email: user.email,
      provider: user.provider,
    };
  }

  return {
    register,
    verifyEmail,
    resendEmailVerification,
    login,
    loginWithGoogle,
    restoreSession,
  };
}

module.exports = {
  AuthError,
  createAuthService,
  hashSecret,
  normalizeEmail,
};
