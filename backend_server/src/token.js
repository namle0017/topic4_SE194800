const crypto = require('node:crypto');

function encode(value) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function sign(data, secret) {
  return crypto.createHmac('sha256', secret).update(data).digest('base64url');
}

function issueToken(payload, secret, now = Date.now()) {
  const issuedAt = Math.floor(now / 1000);
  const header = encode({ alg: 'HS256', typ: 'JWT' });
  const body = encode({ ...payload, iat: issuedAt, exp: issuedAt + 60 * 60 });
  const unsigned = `${header}.${body}`;
  return `${unsigned}.${sign(unsigned, secret)}`;
}

function verifyToken(token, secret, now = Date.now()) {
  try {
    const [header, body, signature, extra] = String(token ?? '').split('.');
    if (!header || !body || !signature || extra) return null;
    const expected = Buffer.from(sign(`${header}.${body}`, secret));
    const received = Buffer.from(signature);
    if (
      expected.length !== received.length ||
      !crypto.timingSafeEqual(expected, received)
    ) {
      return null;
    }

    const payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
    if (!Number.isFinite(payload.exp) || payload.exp <= Math.floor(now / 1000)) {
      return null;
    }
    return payload;
  } catch (_) {
    return null;
  }
}

module.exports = { issueToken, verifyToken };
