function app = launch_histology_browser(rootPath, options)
% launch_histology_browser
%   launch_histology_browser()
%   launch_histology_browser(rootPath)
%   launch_histology_browser(rootPath, metadataCSV = trackerPath)
%   launch_histology_browser(rootPath, publishedUrl = publishedSheetUrl)
%   launch_histology_browser(rootPath, sheetUrl = url, sheetCredentials = keyPath)
%   app = launch_histology_browser(...)
%
% Launch the histology image browser. With no arguments the browser opens on
% the last folder used and waits for the Load Dataset button.
%
% The section tracker can come from three places: the Google Sheet it is
% maintained in, read over the API; the published copy of that sheet; or a CSV
% export of it. The sheet read over the API is always current and is the only
% one a review can be written back to; the published copy is current and needs
% no credentials; the CSV needs no network. They are read in that order, so
% naming a sheet takes precedence over a published URL, which takes precedence
% over a CSV.
%
% Example
%   launch_histology_browser("D:/GM6001_HISTOLOGY/", ...
%       metadataCSV = "D:/GM6001_HISTOLOGY/Trackers - Sections.csv")
%
%   launch_histology_browser("D:/GM6001_HISTOLOGY/", ...
%       publishedUrl = "https://docs.google.com/spreadsheets/d/e/2PACX-.../pub?gid=1084786865&single=true&output=csv")
%
%   launch_histology_browser("D:/GM6001_HISTOLOGY/", ...
%       sheetUrl = "https://docs.google.com/spreadsheets/d/1yz6.../edit", ...
%       sheetCredentials = "C:/keys/histology-sheets.json")
%
% Parameters
%   rootPath: Optional histology root folder to load immediately.
%   options.metadataCSV: Optional section tracker CSV.
%   options.publishedUrl: Optional published sheet URL holding the tracker.
%   options.sheetUrl: Optional spreadsheet URL or ID holding the tracker.
%   options.sheetTab: Tab the tracker is on. Defaults to the saved choice,
%     which starts out as "Sections".
%   options.sheetCredentials: Service account JSON key file for the sheet.
%
% Returns
%   app: The HistologyImageBrowser instance.
%
% See also HISTOLOGYIMAGEBROWSER, SECTIONTRACKER, FETCH_PUBLISHED_TRACKER,
% COMBINE_VALUES_CSV.

arguments
    rootPath (1,1) string = ""
    options.metadataCSV (1,1) string = ""
    options.publishedUrl (1,1) string = ""
    options.sheetUrl (1,1) string = ""
    options.sheetTab (1,1) string = ""
    options.sheetCredentials (1,1) string = ""
end

app = HistologyImageBrowser(rootPath, ...
    metadataCSV = options.metadataCSV, ...
    publishedUrl = options.publishedUrl, ...
    sheetUrl = options.sheetUrl, ...
    sheetTab = options.sheetTab, ...
    sheetCredentials = options.sheetCredentials);

if nargout == 0
    clear app
end

end
