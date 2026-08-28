function encoded = encodeSegment(text)
%ENCODESEGMENT Percent-encode text for use inside a URL path.
% A range travels in the path rather than the query string, so URLENCODE is the
% wrong tool: it writes a space as "+", which a path reads as a literal plus.
% Tab names contain spaces often enough for that to matter.
%
% Parameters
%   text: Text to encode, e.g. an A1 range.
%
% Returns
%   encoded: The same text with reserved characters percent-encoded.

arguments
    text (1,1) string
end

bytes = unicode2native(text, "UTF-8");

if isempty(bytes)
    encoded = "";
    return
end

% Unreserved set from RFC 3986. Everything else is escaped, which is safe even
% where it was not strictly required.
isSafe = (bytes >= uint8('A') & bytes <= uint8('Z')) ...
    | (bytes >= uint8('a') & bytes <= uint8('z')) ...
    | (bytes >= uint8('0') & bytes <= uint8('9')) ...
    | ismember(bytes, uint8('-._~'));

parts = strings(1, numel(bytes));

for iByte = 1:numel(bytes)
    if isSafe(iByte)
        parts(iByte) = string(char(bytes(iByte)));
    else
        parts(iByte) = "%" + upper(string(dec2hex(bytes(iByte), 2)));
    end
end

encoded = join(parts, "");

end
