function csvPath = fetch_published_tracker(publishedUrl, options)
% fetch_published_tracker
%   csvPath = fetch_published_tracker(publishedUrl)
%   csvPath = fetch_published_tracker(publishedUrl, timeout = 60)
%
% Download the section tracker from a published Google Sheet and hand back a
% CSV the rest of the pipeline can read exactly as it reads an exported one.
%
% Publishing a tab (File > Share > Publish to web) gives it a URL that serves
% the tab's contents to anyone who has the URL, with no sign-in and no
% credentials. That is the whole appeal: nothing to authorize, nothing to
% install, and no key file to keep safe. What it costs is that the tracker is
% read-only this way, and that Google caches the published copy, so an edit
% made in the last few minutes may not be in what comes back.
%
% The published copy tracks the sheet on its own as long as "Automatically
% republish when changes are made" is left on, which it is by default.
%
% Parameters
%   publishedUrl: The published URL from the Publish to web dialog. A link
%     serving the tab as a web page is accepted and asked for as CSV instead.
%   options.timeout: Seconds to wait for the download.
%   options.fetch: What to download with, as fetch(url, timeout) returning the
%     reply as text. Defaults to WEBREAD. It is a parameter because everything
%     around the download -- which URLs are accepted, how they are rewritten,
%     and catching a reply that is not CSV -- is worth testing, and WEBREAD
%     will not read a file URL, so there is no way to stand in for the server
%     without one.
%
% Returns
%   csvPath: Path to a temporary CSV file. The caller owns it and should
%     delete it once it has been read.
%
% Example
%   csvPath = fetch_published_tracker(url);
%   cleanup = onCleanup(@() delete(csvPath));
%   S = combine_values_csv(rootPath, metadataCSV = csvPath);
%
% See also COMBINE_VALUES_CSV, LAUNCH_HISTOLOGY_BROWSER.

arguments
    publishedUrl (1,1) string
    options.timeout (1,1) double = 60
    options.fetch = @download
end

url = normalize_published_url(publishedUrl);

try
    text = string(options.fetch(url, options.timeout));
catch ME
    if startsWith(ME.identifier, "fetch_published_tracker:")
        rethrow(ME)
    end

    error("fetch_published_tracker:DownloadFailed", ...
        "Could not download the published sheet: %s\n\nCheck the URL, and " + ...
        "that the sheet is still published.", ME.message)
end

check_looks_like_csv(text, url);

csvPath = string([tempname '.csv']);

% Written as UTF-8 rather than in whatever the machine's locale is, because
% micrometre and degree signs turn up in tracker notes and would otherwise be
% mangled on the way to disk.
fid = fopen(csvPath, "w", "n", "UTF-8");

if fid < 0
    error("fetch_published_tracker:CannotWrite", ...
        "Could not open a temporary file to hold the tracker: %s", csvPath)
end

closeFile = onCleanup(@() fclose(fid));
fprintf(fid, "%s", text);

end

function text = download(url, timeout)
%DOWNLOAD Fetch the published tab over HTTP.

text = webread(url, weboptions(ContentType = "text", Timeout = timeout));

end

function url = normalize_published_url(publishedUrl)
%NORMALIZE_PUBLISHED_URL Turn a published link into the one that serves CSV.
% The Publish to web dialog offers a format, and someone who left it on the
% default gets a link serving a web page. That link names the right document
% and the right tab, so it is asked for as CSV rather than refused.

url = strtrim(publishedUrl);

if url == ""
    error("fetch_published_tracker:NoUrl", "No published sheet URL was given.")
end

% Anchors are for the browser and mean nothing to the server.
url = extractBefore(url + "#", "#");

% A published document lives under /d/e/ and carries a key of its own that is
% not the spreadsheet ID. An ordinary edit URL is the single most likely thing
% to be pasted here, and it will never work, so it is named for what it is.
if ~contains(url, "/spreadsheets/d/e/")
    error("fetch_published_tracker:NotPublished", ...
        "That is a link to the spreadsheet, not a published copy of it.\n\n" + ...
        "In the sheet, choose File > Share > Publish to web, pick the " + ...
        "Sections tab and the CSV format, publish it, and paste the link " + ...
        "that gives you. A published link contains '/d/e/'.")
end

% The web-page form is served from /pubhtml; CSV comes from /pub.
url = replace(url, "/pubhtml", "/pub");

if contains(url, "output=")
    url = regexprep(url, "output=[^&]*", "output=csv");
elseif contains(url, "?")
    url = url + "&output=csv";
else
    url = url + "?output=csv";
end

end

function check_looks_like_csv(text, url)
%CHECK_LOOKS_LIKE_CSV Refuse a web page pretending to be the tracker.
% A URL that is no longer published, or was never published, still answers:
% Google serves an HTML page saying so. Handing that to READTABLE would give a
% baffling parse error a long way from the cause, so it is caught here.

trimmed = strtrim(text);

if trimmed == ""
    error("fetch_published_tracker:EmptySheet", ...
        "The published sheet returned nothing. Check that the tab being " + ...
        "published is the one holding the tracker.")
end

opening = lower(char(trimmed));

if numel(opening) > 600
    opening = opening(1:600);
end

if startsWith(trimmed, "<") || contains(opening, "<!doctype html") || contains(opening, "<html")
    error("fetch_published_tracker:NotCsv", ...
        "%s returned a web page rather than CSV.\n\nThe usual cause is that " + ...
        "the sheet is no longer published: open File > Share > Publish to " + ...
        "web and check the Sections tab is still listed there.", url)
end

end
