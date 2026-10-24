const crypto = require('crypto');
const { createAuthService } = require('./src/auth_service');
const { InMemoryAuthStore } = require('./src/auth_store');
const { loadConfig } = require('./src/config');
const { createHttpServer } = require('./src/http_app');
const { createOtpSender } = require('./src/otp_sender');
const { verifySupabaseToken } = require('./src/supabase_verifier');

const config = loadConfig();
const secret = config.jwtSecret || crypto.randomBytes(32).toString('hex');
const otpSender = createOtpSender(config);
const authService = createAuthService({
  store: new InMemoryAuthStore(),
  secret,
  generateOtp: () =>
    config.devOtp || String(crypto.randomInt(0, 1000000)).padStart(6, '0'),
  sendOtp: (message) => otpSender.send(message),
});
const verifyGoogleToken = (accessToken) =>
  verifySupabaseToken(accessToken, {
    url: config.supabaseUrl,
    publishableKey: config.supabasePublishableKey,
  });

createHttpServer({ authService, verifyGoogleToken }).listen(config.port, () => {
  console.log(`Auth API chạy tại http://localhost:${config.port}`);
});
