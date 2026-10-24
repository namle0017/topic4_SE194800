const nodemailer = require('nodemailer');
const { AuthError } = require('./auth_service');

function createOtpSender(config, { createTransport = nodemailer.createTransport } = {}) {
  if (config.devOtp) {
    return {
      async send() {},
    };
  }

  const { smtp } = config;
  if (!smtp.host || !smtp.from) {
    return {
      async send() {
        throw new AuthError(
          503,
          'Email delivery is not configured. Set DEV_OTP for a local demo or configure SMTP.',
        );
      },
    };
  }

  const transport = createTransport({
    host: smtp.host,
    port: smtp.port,
    secure: smtp.secure,
    auth: smtp.user && smtp.pass
      ? { user: smtp.user, pass: smtp.pass }
      : undefined,
  });
  return {
    async send({ email, otp }) {
      try {
        await transport.sendMail({
          from: smtp.from,
          to: email,
          subject: 'Your email verification code',
          text: `Your verification code is ${otp}. It expires in 10 minutes.`,
        });
      } catch (_) {
        throw new AuthError(502, 'Could not send the verification email.');
      }
    },
  };
}

module.exports = { createOtpSender };
