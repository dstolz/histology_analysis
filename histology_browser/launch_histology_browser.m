function app = launch_histology_browser(rootPath, options)
% launch_histology_browser
%   launch_histology_browser()
%   launch_histology_browser(rootPath)
%   launch_histology_browser(rootPath, metadataCSV = trackerPath)
%   app = launch_histology_browser(...)
%
% Launch the histology image browser. With no arguments the browser opens on
% the last folder used and waits for the Load Dataset button.
%
% Example
%   launch_histology_browser("D:/GM6001_HISTOLOGY/", ...
%       metadataCSV = "D:/GM6001_HISTOLOGY/Trackers - Sections.csv")
%
% Parameters
%   rootPath: Optional histology root folder to load immediately.
%   options.metadataCSV: Optional section tracker CSV.
%
% Returns
%   app: The HistologyImageBrowser instance.
%
% See also HISTOLOGYIMAGEBROWSER, COMBINE_VALUES_CSV.

arguments
    rootPath (1,1) string = ""
    options.metadataCSV (1,1) string = ""
end

app = HistologyImageBrowser(rootPath, metadataCSV = options.metadataCSV);

if nargout == 0
    clear app
end

end
