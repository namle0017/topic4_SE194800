function read(env, key) {
  return String(env[key] ?? '').trim();
}

function loadConfig(env = process.env) {
  const smtpPort = Number(read(env, 'SMTP_PORT') || 587);
  return {
    port: Number(read(env, 'PORT') || 8080),
    jwtSecret: read(env, 'JWT_SECRET'),
    devOtp: read(env, 'DEV_OTP'),
    smtp: {
      host: read(env, 'SMTP_HOST'),
      port: Number.isFinite(smtpPort) ? smtpPort : 587,
      secure: read(env, 'SMTP_SECURE').toLowerCase() === 'true',
      user: read(env, 'SMTP_USER'),
      pass: read(env, 'SMTP_PASS'),
      from: read(env, 'SMTP_FROM'),
    },
    supabaseUrl: read(env, 'SUPABASE_URL').replace(/\/$/, ''),
    supabasePublishableKey: read(env, 'SUPABASE_PUBLISHABLE_KEY'),
  };
}

module.exports = { loadConfig };
