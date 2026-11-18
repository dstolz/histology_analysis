%%

startup

addpath_nogit('C:\src\histology_analysis')
addpath_nogit('c:\src\bfmatlab')

%%
HistologyImageBrowser;


%% Save exported histology data
% (histdb.saveTracked writes the same file as save, and records which values,
% ROI and surface files the table was read from beside it)
histdb.saveTracked("histology_ACxProfiles.mat", "histology", histology);

%% Reload histology data and combine with ECM Projects csv
load("histology_ACxProfiles.mat")

projectFile = "D:/GM6001_HISTOLOGY/ECM Projects - GM6001.csv";
ffnOut = "D:/GM6001_HISTOLOGY/ECM Projects - GM6001 - full.mat";

% attach project info (drug/vehicle assigned per hemisphere, cannula
% distance) and save
histology = ecm_attach_project_info(histology, projectFile, SaveTo = ffnOut, ...
    InputFiles = fullfile(pwd, "histology_ACxProfiles.mat"));

% export for R
ecm_export_for_r(ffnOut,"D:/GM6001_HISTOLOGY")


%% prep data for analysis

voi = ["SubjectID", "AtlasPlate", "Treatment"];
% voi = ["SubjectID", "AtlasPlate", "Hemisphere"];


A = ecm_prepare_analysis_data(histology, ...
    fileVar = "ImagePath", ...
    groupVars = voi, ...
    smoothingMethod = "gaussian", ...
    smoothingWindow = 25, ...
    normalizeMode = "none", ...
    sourceFiles = ffnOut);


B = launch_ecm_browser(A);

%% All Conditions by Atlas Plate
% The ECM Browser view of 2026-10-01 11:00, as commands.
% Everything not named here is what a browser opens on.
B.ShowDropDown.Value = "group mean";
B.GroupDropDown.Value = "Treatment";
B.setTiling("AtlasPlate");
B.setFilter("AtlasPlate", ["28" "29" "30" "31" "32"]);
B.setFilter("IncludeInAnalysis", "TRUE");
B.DepthMinField.Value = 0;
B.DepthMaxField.Value = 1700;
B.SpacingDropDown.Value = "none";
B.TickLabelDropDown.Value = "left and bottom axes";
B.refresh();

% And what can then be done with it:
%   B.popOut()                                                   draws it into a figure of its own
%   B.savePlot("figure.pdf")                                     PNG, TIFF, JPEG, PDF, EPS, SVG, or .fig
%   B.saveData("profiles.csv", Layout = "long")                  one row per sample, every field beside it
%   d = B.viewData()                                             the numbers behind the plot
%   B.copySummary()                                              the account of this view a caption needs
%   B.setGroupStyle("Treatment", "Control L", Color = [0 0 0])   one group in a color of your own


%% Compare Atlas Plate vs Cannula distance
% The ECM Browser view of 2026-10-01 10:59, as commands.
% Everything not named here is what a browser opens on.
B.ShowDropDown.Value = "group mean";
B.GroupDropDown.Value = "Treatment";
B.setTiling(["AtlasPlate" "CannulaDist"]);
B.setFilter("AtlasPlate", ["28" "29" "30" "31" "32"]);
B.setFilter("IncludeInAnalysis", "TRUE");
B.DepthMinField.Value = 0;
B.DepthMaxField.Value = 1700;
B.SpacingDropDown.Value = "none";
B.TickLabelDropDown.Value = "left and bottom axes";
B.refresh();

% And what can then be done with it:
%   B.popOut()                                                   draws it into a figure of its own
%   B.savePlot("figure.pdf")                                     PNG, TIFF, JPEG, PDF, EPS, SVG, or .fig
%   B.saveData("profiles.csv", Layout = "long")                  one row per sample, every field beside it
%   d = B.viewData()                                             the numbers behind the plot
%   B.copySummary()                                              the account of this view a caption needs
%   B.setGroupStyle("Treatment", "Control L", Color = [0 0 0])   one group in a color of your own

%% Compare Treatment to Vehicle by Atlas Plate distance to Cannula site
% The ECM Browser view of 2026-09-25 15:12, as commands.
% Everything not named here is what a browser opens on.
B.setComparison("log2 ratio", "Treatment", ...
    reference = "Vehicle", within = "Treatment");
B.GroupDropDown.Value = "SubjectID";
B.setTiling("CannulaDist");
B.setFilter("IncludeInAnalysis", "TRUE");
B.setFilter("Condition", "Trained");
B.setFilter("AtlasPlate", ["28" "29" "30" "31" "32"]);
B.DepthMinField.Value = 0;
B.DepthMaxField.Value = 1600;
B.refresh();

% And what can then be done with it:
%   B.popOut()                                                      draws it into a figure of its own
%   B.savePlot("figure.pdf")                                        PNG, TIFF, JPEG, PDF, EPS, SVG, or .fig
%   B.saveData("profiles.csv", Layout = "long")                     one row per sample, every field beside it
%   d = B.viewData()                                                the numbers behind the plot
%   B.copySummary()                                                 the account of this view a caption needs
%   B.setGroupStyle("SubjectID", "SUBJ-ID-1174", Color = [0 0 0])   one group in a color of your own

%%
% The ECM Browser view of 2026-09-07 14:53, as commands.
% Everything not named here is what a browser opens on.
B.setComparison("difference", "Treatment", ...
    reference = "Vehicle", within = "AtlasPlate");
B.GroupDropDown.Value = "SubjectID";
B.setTiling("AtlasPlate");
B.setFilter("IncludeInAnalysis", "TRUE");
B.setFilter("Condition", "Trained");
B.setFilter("AtlasPlate", ["28" "29" "30" "31" "32"]);
B.DepthMinField.Value = 0;
B.DepthMaxField.Value = 2000;
B.SpacingDropDown.Value = "none";
B.TickLabelDropDown.Value = "left and bottom axes";
B.refresh();

% And what can then be done with it:
%   B.popOut()                                                      draws it into a figure of its own
%   B.savePlot("figure.pdf")                                        PNG, TIFF, JPEG, PDF, EPS, SVG, or .fig
%   B.saveData("profiles.csv", Layout = "long")                     one row per sample, every field beside it
%   d = B.viewData()                                                the numbers behind the plot
%   B.copySummary()                                                 the account of this view a caption needs
%   B.setGroupStyle("SubjectID", "SUBJ-ID-1174", Color = [0 0 0])   one group in a color of your own


%% GM6001 - Vehicle within sections
% The ECM Browser view of 2026-09-04 15:53, as commands.
% Everything not named here is what a browser opens on.
B.setComparison("difference", "Treatment", ...
    reference = "Vehicle", within = ["SubjectID" "AtlasPlate"]);
B.GroupDropDown.Value = "SubjectID";
B.setTiling("AtlasPlate");
B.setFilter("IncludeInAnalysis", "TRUE");
B.setFilter("Condition", "Trained");
B.DepthMinField.Value = 0;
B.DepthMaxField.Value = 1600;
B.refresh();

% And what can then be done with it:
%   B.popOut()                                                      draws it into a figure of its own
%   B.savePlot("figure.pdf")                                        PNG, TIFF, JPEG, PDF, EPS, SVG, or .fig
%   B.saveData("profiles.csv", Layout = "long")                     one row per sample, every field beside it
%   d = B.viewData()                                                the numbers behind the plot
%   B.copySummary()                                                 the account of this view a caption needs
%   B.setGroupStyle("SubjectID", "SUBJ-ID-1174", Color = [0 0 0])   one group in a color of your own

%% Compare Treated vs Controls by Atlas Plate
% The ECM Browser view of 2026-09-08 12:06, as commands.
% Everything not named here is what a browser opens on.
B.ShowDropDown.Value = "group mean";
B.GroupDropDown.Value = "Treatment";
B.setTiling(["AtlasPlate" "Condition"]);
B.setFilter("IncludeInAnalysis", "TRUE");
B.setFilter("AtlasPlate", ["28" "29" "30" "31" "32"]);
B.DepthMinField.Value = 0;
B.DepthMaxField.Value = 2000;
B.SpacingDropDown.Value = "none";
B.TickLabelDropDown.Value = "left and bottom axes";
B.refresh();

% And what can then be done with it:
%   B.popOut()                                                   draws it into a figure of its own
%   B.savePlot("figure.pdf")                                     PNG, TIFF, JPEG, PDF, EPS, SVG, or .fig
%   B.saveData("profiles.csv", Layout = "long")                  one row per sample, every field beside it
%   d = B.viewData()                                             the numbers behind the plot
%   B.copySummary()                                              the account of this view a caption needs
%   B.setGroupStyle("Treatment", "Control L", Color = [0 0 0])   one group in a color of your own