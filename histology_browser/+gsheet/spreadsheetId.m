function id = spreadsheetId(reference)
%SPREADSHEETID Reduce a spreadsheet URL to the ID the API wants.
% What people have to hand is the address bar, so pasting a full edit URL is
% the expected way to name a sheet. An ID given on its own passes through
% unchanged, which lets the same field accept either.
%
%   gsheet.spreadsheetId("https://docs.google.com/spreadsheets/d/1abc.../edit#gid=0")
%   gsheet.spreadsheetId("1abc...")
%
% Parameters
%   reference: Spreadsheet URL or bare ID.
%
% Returns
%   id: The spreadsheet ID.

arguments
    reference (1,1) string
end

id = strtrim(reference);

if id == ""
    error("gsheet:NoSpreadsheet", "No spreadsheet URL or ID was given.")
end

matched = regexp(id, "/spreadsheets/d/(?<id>[A-Za-z0-9_-]+)", "names", "once");

if ~isempty(matched)
    id = string(matched.id);
    return
end

if ~isempty(regexp(id, "^[A-Za-z0-9_-]+$", "once"))
    return
end

error("gsheet:UnrecognizedSpreadsheet", ...
    "'%s' is neither a spreadsheet ID nor a spreadsheet URL.", reference)

end
