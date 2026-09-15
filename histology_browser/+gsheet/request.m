function payload = request(method, url, options)
%REQUEST Issue one Google API call and decode the JSON reply.
% Every call in this package goes through here so authentication, the JSON
% round trip, and Google's error format are handled in exactly one place.
%
% MATLAB.NET.HTTP is used rather than WEBREAD/WEBWRITE because the Sheets API
% reports refusals in the response body, not just the status line: a bad range,
% or a sheet the service account cannot reach, comes back as JSON naming the
% problem. WEBWRITE would raise a bare "400 Bad Request" and discard it.
%
% Parameters
%   method: HTTP verb, e.g. "GET" or "POST".
%   url: Fully qualified request URL, already percent-encoded.
%   options.token: OAuth bearer token. Omitted for the token request itself.
%   options.body: Request body text. Empty sends no body.
%   options.contentType: Media type of the body.
%   options.timeout: Connect and response timeout, in seconds.
%
% Returns
%   payload: Decoded JSON reply, as a struct.

arguments
    method (1,1) string
    url (1,1) string
    options.token (1,1) string = ""
    options.body (1,1) string = ""
    options.contentType (1,1) string = "application/json"
    options.timeout (1,1) double = 30
end

headers = matlab.net.http.HeaderField.empty;

if options.token ~= ""
    headers(end+1) = matlab.net.http.HeaderField("Authorization", "Bearer " + options.token);
end

if options.body == ""
    message = matlab.net.http.RequestMessage(method, headers);
else
    headers(end+1) = matlab.net.http.HeaderField("Content-Type", options.contentType);

    % The payload is set as raw bytes rather than as Data, because MATLAB
    % re-encodes Data according to the content type and would wrap already
    % serialized JSON in a second layer of quoting.
    body = matlab.net.http.MessageBody;
    body.Payload = unicode2native(options.body, "UTF-8");

    message = matlab.net.http.RequestMessage(method, headers, body);
end

httpOptions = matlab.net.http.HTTPOptions( ...
    ConnectTimeout = options.timeout, ...
    ResponseTimeout = options.timeout);

try
    response = message.send(matlab.net.URI(url), httpOptions);
catch ME
    error("gsheet:RequestFailed", ...
        "Could not reach %s: %s", url, ME.message)
end

status = double(response.StatusCode);

if status < 200 || status > 299
    error("gsheet:HttpError", ...
        "Google returned %d for %s %s: %s", ...
        status, method, url, describe_error(response));
end

payload = response.Body.Data;

if ischar(payload) || isstring(payload)
    payload = jsondecode(char(payload));
end

if isempty(payload)
    payload = struct();
end

end

function text = describe_error(response)
%DESCRIBE_ERROR Pull the human-readable reason out of an error response.
% Google nests it under error.message; anything else is passed through as-is so
% an unexpected shape still reaches the caller instead of being swallowed.

data = response.Body.Data;

if (ischar(data) || isstring(data)) && strlength(string(data)) > 0
    try
        data = jsondecode(char(data));
    catch
        text = strtrim(string(data));
        return
    end
end

if isstruct(data) && isfield(data, "error")
    detail = data.error;

    if isstruct(detail) && isfield(detail, "message")
        text = string(detail.message);
        return
    end

    if ischar(detail) || isstring(detail)
        text = string(detail);
        return
    end
end

text = string(response.StatusLine.ReasonPhrase);

end
