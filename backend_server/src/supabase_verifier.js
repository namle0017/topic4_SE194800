const { AuthError } = require('./auth_service');

async function verifySupabaseToken(
  accessToken,
  { url, publishableKey, fetchImpl = fetch },
) {
  if (!accessToken) {
    throw new AuthError(400, 'Supabase access token is required.');
  }
  if (!url || !publishableKey) {
    throw new AuthError(503, 'Supabase authentication is not configured.');
  }

  let response;
  try {
    response = await fetchImpl(`${url}/auth/v1/user`, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        apikey: publishableKey,
      },
    });
  } catch (_) {
    throw new AuthError(502, 'Could not reach Supabase authentication.');
  }

  if (response.status === 401 || response.status === 403) {
    throw new AuthError(401, 'Google authentication token is invalid.');
  }
  if (!response.ok) {
    throw new AuthError(502, 'Supabase authentication returned an error.');
  }

  let user;
  try {
    user = await response.json();
  } catch (_) {
    throw new AuthError(502, 'Supabase authentication returned invalid data.');
  }
  const email = String(user.email ?? '').trim().toLowerCase();
  if (!email) {
    throw new AuthError(502, 'Supabase user does not contain an email address.');
  }
  return {
    email,
    name: String(
      user.user_metadata?.full_name ??
      user.user_metadata?.name ??
      email.split('@')[0],
    ).trim(),
  };
}

module.exports = { verifySupabaseToken };
