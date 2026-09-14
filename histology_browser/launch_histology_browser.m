function app = launch_histology_browser(rootPath, options)
% launch_histology_browser
%   launch_histology_browser()
%   launch_histology_browser(rootPath)
%   launch_histology_browser(rootPath, metadataCSV = trackerPath)
%   launch_histology_browser(rootPath, publishedUrl = publishedSheetUrl)
%   app = launch_histology_browser(...)
%
% Launch the histology image browser. With no arguments the browser opens on
% the last folder used and waits for the Load Dataset button.
%
% The section tracker can come from a CSV export or from the published copy of
% the Google Sheet it is maintained in. The published sheet saves exporting it
% by hand every time it changes; the CSV needs no network. Naming a published
% sheet takes precedence over naming a CSV.
%
% Example
%   launch_histology_browser("D:/GM6001_HISTOLOGY/", ...
%       metadataCSV = "D:/GM6001_HISTOLOGY/Trackers - Sections.csv")
%
%   launch_histology_browser("D:/GM6001_HISTOLOGY/", ...
%       publishedUrl = "https://docs.google.com/spreadsheets/d/e/2PACX-.../pub?gid=1084786865&single=true&output=csv")
%
% Parameters
%   rootPath: Optional histology root folder to load immediately.
%   options.metadataCSV: Optional section tracker CSV.
%   options.publishedUrl: Optional published sheet URL holding the tracker.
%
% Returns
%   app: The HistologyImageBrowser instance.
%
% See also HISTOLOGYIMAGEBROWSER, FETCH_PUBLISHED_TRACKER, COMBINE_VALUES_CSV.

arguments
    rootPath (1,1) string = ""
    options.metadataCSV (1,1) string = ""
    options.publishedUrl (1,1) string = ""
end

app = HistologyImageBrowser(rootPath, ...
    metadataCSV = options.metadataCSV, ...
    publishedUrl = options.publishedUrl);

if nargout == 0
    clear app
end

end
