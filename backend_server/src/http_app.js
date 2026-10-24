const http = require('node:http');
const { AuthError } = require('./auth_service');

const BODY_LIMIT_BYTES = 64 * 1024;

function sendJson(response, status, body) {
  response.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  });
  response.end(JSON.stringify(body));
}

async function readJson(request) {
  let raw = '';
  let bytes = 0;
  for await (const chunk of request) {
    bytes += chunk.length;
    if (bytes > BODY_LIMIT_BYTES) {
      throw new AuthError(413, 'Request body is too large.');
    }
    raw += chunk;
  }
  if (!raw) return {};
  try {
    return JSON.parse(raw);
  } catch (_) {
    throw new AuthError(400, 'Invalid JSON body.');
  }
}

function createHttpServer({ authService, verifyGoogleToken }) {
  return http.createServer(async (request, response) => {
    if (request.method === 'OPTIONS') {
      return sendJson(response, 204, {});
    }

    try {
      if (request.method === 'POST' && request.url === '/api/auth/register') {
        const result = await authService.register(await readJson(request));
        return sendJson(response, 202, {
          success: true,
          code: 202,
          message: 'Registration successful. Verify your email to continue.',
          result,
        });
      }

      if (
        request.method === 'POST' &&
        request.url === '/api/auth/email-verification/verify'
      ) {
        await authService.verifyEmail(await readJson(request));
        return sendJson(response, 200, {
          success: true,
          code: 200,
          message: 'Email verified successfully. You can now sign in.',
        });
      }

      if (
        request.method === 'POST' &&
        request.url === '/api/auth/email-verification/resend'
      ) {
        const result = await authService.resendEmailVerification(
          await readJson(request),
        );
        return sendJson(response, 200, {
          success: true,
          code: 200,
          message: 'A new verification code was sent.',
          result,
        });
      }

      if (request.method === 'POST' && request.url === '/api/auth/login') {
        const result = await authService.login(await readJson(request));
        return sendJson(response, 200, {
          success: true,
          code: 200,
          message: 'Signed in successfully.',
          result,
        });
      }

      if (request.method === 'GET' && request.url === '/api/me') {
        const authorization = request.headers.authorization ?? '';
        const token = authorization.startsWith('Bearer ')
          ? authorization.slice('Bearer '.length)
          : '';
        const result = await authService.restoreSession(token);
        return sendJson(response, 200, {
          success: true,
          code: 200,
          message: 'Session restored.',
          result,
        });
      }

      if (
        request.method === 'POST' &&
        request.url === '/api/auth/google'
      ) {
        if (!verifyGoogleToken) {
          throw new AuthError(503, 'Google authentication is not configured.');
        }
        const { accessToken } = await readJson(request);
        const googleUser = await verifyGoogleToken(accessToken);
        const result = await authService.loginWithGoogle(googleUser);
        return sendJson(response, 200, {
          success: true,
          code: 200,
          message: 'Signed in with Google successfully.',
          result,
        });
      }

      return sendJson(response, 404, {
        success: false,
        code: 404,
        message: 'Not found.',
      });
    } catch (error) {
      const status = error instanceof AuthError ? error.status : 500;
      return sendJson(response, status, {
        success: false,
        code: status,
        message: status === 500 ? 'Internal server error.' : error.message,
      });
    }
  });
}

module.exports = { BODY_LIMIT_BYTES, createHttpServer };
