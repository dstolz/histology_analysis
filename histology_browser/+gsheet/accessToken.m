function token = accessToken(credentialsPath, options)
%ACCESSTOKEN Exchange a service account key for an OAuth bearer token.
% Google grants tokens to a service account by way of a JWT that the account
% signs with its own private key. There is no browser step and no refresh
% token, which is the whole reason this is the auth route that suits a MATLAB
% app: the key file sits on disk, and nothing has to be re-authorized by hand.
%
% Tokens last an hour, so they are cached in memory per key file and reused
% until they are close to expiring. A sitting with the browser therefore costs
% one token request, not one per read.
%
% Parameters
%   credentialsPath: Path to the service account JSON key file.
%   options.scope: OAuth scope to request. The default allows reads and writes.
%   options.forceRefresh: Request a new token even if a cached one is valid.
%
% Returns
%   token: Bearer token string.
%
% See also GSHEET.JWTASSERTION, GSHEET.SERVICEACCOUNT, GSHEET.REQUEST.

arguments
    credentialsPath (1,1) string
    options.scope (1,1) string = "https://www.googleapis.com/auth/spreadsheets"
    options.forceRefresh (1,1) logical = false
end

% Keyed by file and scope, because a read-only scope and a read-write scope are
% different grants and must not be served from the same entry.
persistent cache

if isempty(cache)
    cache = containers.Map("KeyType", "char", "ValueType", "any");
end

cacheKey = char(strtrim(credentialsPath) + "|" + options.scope);

if ~options.forceRefresh && isKey(cache, cacheKey)
    entry = cache(cacheKey);

    % A minute of headroom, so a token cannot expire between being handed out
    % and the request that uses it arriving at Google.
    if entry.expiresAt - datetime("now", TimeZone = "UTC") > minutes(1)
        token = entry.token;
        return
    end
end

credentials = gsheet.serviceAccount(credentialsPath);
assertion = gsheet.jwtAssertion(credentials, options.scope);

payload = gsheet.request("POST", credentials.token_uri, ...
    body = "grant_type=" + urlencode("urn:ietf:params:oauth:grant-type:jwt-bearer") ...
        + "&assertion=" + assertion, ...
    contentType = "application/x-www-form-urlencoded");

if ~isfield(payload, "access_token")
    error("gsheet:NoAccessToken", ...
        "Google accepted the request but returned no access token for %s.", ...
        credentials.client_email)
end

token = string(payload.access_token);

lifetime = 3600;

if isfield(payload, "expires_in")
    lifetime = double(payload.expires_in);
end

cache(cacheKey) = struct( ...
    token = token, ...
    expiresAt = datetime("now", TimeZone = "UTC") + seconds(lifetime));

end
