function credentials = serviceAccount(credentialsPath)
%SERVICEACCOUNT Read and check a service account key file.
% A user-account key, or a key downloaded in the wrong format, is valid JSON
% and decodes cleanly, then fails much later inside a Java signing call with a
% message about key specs. The shape is checked here instead, where the error
% can still name the file and say what to download.
%
% Parameters
%   credentialsPath: Path to the service account JSON key file.
%
% Returns
%   credentials: Struct with at least client_email, private_key, token_uri.
%
% See also GSHEET.JWTASSERTION, GSHEET.ACCESSTOKEN.

arguments
    credentialsPath (1,1) string
end

credentialsPath = strtrim(credentialsPath);

if credentialsPath == ""
    error("gsheet:NoCredentials", ...
        "No service account key file is configured. See README.md, " + ...
        "'Reading the tracker from Google Sheets', for how to create one.")
end

if ~isfile(credentialsPath)
    error("gsheet:MissingCredentials", ...
        "The service account key file does not exist: %s", credentialsPath)
end

try
    credentials = jsondecode(fileread(credentialsPath));
catch ME
    error("gsheet:UnreadableCredentials", ...
        "%s is not valid JSON: %s", credentialsPath, ME.message)
end

required = ["client_email", "private_key"];
missing = required(~isfield(credentials, required));

if ~isempty(missing)
    error("gsheet:IncompleteCredentials", ...
        "%s is missing %s. Download the JSON key for a service account, " + ...
        "not an OAuth client ID.", credentialsPath, strjoin(missing, " and "))
end

if isfield(credentials, "type") && string(credentials.type) ~= "service_account"
    error("gsheet:WrongCredentialType", ...
        "%s is a '%s' credential. A 'service_account' key is required.", ...
        credentialsPath, string(credentials.type))
end

if ~isfield(credentials, "token_uri") || string(credentials.token_uri) == ""
    credentials.token_uri = "https://oauth2.googleapis.com/token";
end

credentials.token_uri = string(credentials.token_uri);
credentials.client_email = string(credentials.client_email);

end
