function assertion = jwtAssertion(credentials, scope, issuedAt)
%JWTASSERTION Build the signed JWT a service account trades for a token.
% Google grants a token to whoever can prove they hold the service account's
% private key, and the proof is this: a header and a set of claims, each
% base64url encoded, joined by a dot and signed with RSA-SHA256.
%
% The signing goes through Java because MATLAB has no RSA primitive of its own.
% MATLAB ships a JVM and the browser needs one anyway for UIFIGURE, so this
% adds no dependency the app did not already have.
%
% Parameters
%   credentials: Struct from GSHEET.SERVICEACCOUNT.
%   scope: OAuth scope being requested.
%   issuedAt: POSIX time the assertion is issued at.
%
% Returns
%   assertion: The signed JWT, ready to post to the token endpoint.
%
% See also GSHEET.ACCESSTOKEN, GSHEET.SERVICEACCOUNT.

arguments
    credentials (1,1) struct
    scope (1,1) string
    issuedAt (1,1) double = posixtime(datetime("now", TimeZone = "UTC"))
end

header = struct(alg = "RS256", typ = "JWT");

if isfield(credentials, "private_key_id")
    header.kid = string(credentials.private_key_id);
end

claims = struct( ...
    iss = credentials.client_email, ...
    scope = scope, ...
    aud = credentials.token_uri, ...
    iat = floor(issuedAt), ...
    exp = floor(issuedAt) + 3600);

signingInput = base64url(unicode2native(jsonencode(header), "UTF-8")) ...
    + "." + base64url(unicode2native(jsonencode(claims), "UTF-8"));

signature = sign_rs256(credentials.private_key, signingInput);

assertion = signingInput + "." + base64url(signature);

end

function signature = sign_rs256(privateKeyPem, signingInput)
%SIGN_RS256 Sign the JWT body with the service account's RSA key.

if ~usejava("jvm")
    error("gsheet:NoJvm", ...
        "Signing the service account assertion needs the JVM, but MATLAB " + ...
        "was started with -nojvm.")
end

key = decode_private_key(privateKeyPem);

signer = java.security.Signature.getInstance("SHA256withRSA");
signer.initSign(key);
signer.update(to_java_bytes(unicode2native(signingInput, "UTF-8")));

signature = typecast(signer.sign(), "uint8");

end

function key = decode_private_key(privateKeyPem)
%DECODE_PRIVATE_KEY Turn the PEM block in the key file into an RSA key.
% Google issues PKCS#8 keys ("BEGIN PRIVATE KEY"). A PKCS#1 block decodes to
% bytes that PKCS8EncodedKeySpec rejects with an opaque Java error about
% algorithm identifiers, so it is recognized and named here instead.

pem = string(privateKeyPem);

if contains(pem, "BEGIN RSA PRIVATE KEY")
    error("gsheet:UnsupportedKeyFormat", ...
        "The private key is in PKCS#1 format. Google service account keys " + ...
        "are PKCS#8; re-download the key as JSON rather than converting it.")
end

if ~contains(pem, "BEGIN PRIVATE KEY")
    error("gsheet:UnsupportedKeyFormat", ...
        "The private_key field does not contain a PEM private key block.")
end

body = extractBetween(pem, "-----BEGIN PRIVATE KEY-----", "-----END PRIVATE KEY-----");
body = regexprep(body(1), "\s", "");

der = matlab.net.base64decode(body);

try
    keySpec = java.security.spec.PKCS8EncodedKeySpec(to_java_bytes(der));
    key = java.security.KeyFactory.getInstance("RSA").generatePrivate(keySpec);
catch ME
    error("gsheet:UnreadablePrivateKey", ...
        "The private key could not be decoded: %s", ME.message)
end

end

function bytes = to_java_bytes(data)
%TO_JAVA_BYTES Reinterpret bytes as the signed type Java expects.
% Java has no unsigned byte, so anything above 127 has to be handed over as its
% negative counterpart rather than being clamped or widened.

bytes = typecast(uint8(data(:)), "int8");

end

function text = base64url(bytes)
%BASE64URL Encode bytes in the URL-safe, unpadded alphabet JWTs use.

text = string(matlab.net.base64encode(uint8(bytes(:))));
text = replace(text, "+", "-");
text = replace(text, "/", "_");
text = erase(text, "=");

end
