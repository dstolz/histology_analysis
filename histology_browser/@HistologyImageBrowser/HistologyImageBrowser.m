classdef HistologyImageBrowser < handle
    %HISTOLOGYIMAGEBROWSER Browse histology images and overlay line-profile data.
    %
    %   app = HistologyImageBrowser()
    %   app = HistologyImageBrowser(rootPath)
    %   app = HistologyImageBrowser(rootPath, metadataCSV = trackerPath)
    %
    % Loads a histology root folder with COMBINE_VALUES_CSV, catalogs every
    % image rendition found beside the values files, and provides filtered
    % lookup plus single or multi-image display. The line ROIs written by the
    % Fiji line-measure macro can be overlaid on each image, optionally shaded
    % by the intensities recorded in the matching *values.csv file.
    %
    % A section may carry several line ROIs, one per region measured across
    % it. Each is keyed by the letter in its filenames -- A, B, C, and so on,
    % with the macro's unlabelled pair taken as A -- and each key can be given
    % the region's own name, so a study that measures auditory and
    % somatosensory cortex reads as ACx and S1 wherever an ROI is drawn,
    % plotted, or listed. Those names persist between sessions.
    %
    % See also COMBINE_VALUES_CSV, BUILD_HISTOLOGY_IMAGE_CATALOG,
    % HISTOLOGY_ROI_KEY, READ_IMAGEJ_ROI, LAUNCH_HISTOLOGY_BROWSER.

    properties
        Fig matlab.ui.Figure
        MainGrid matlab.ui.container.GridLayout
        ContentGrid matlab.ui.container.GridLayout
        BrowseGrid matlab.ui.container.GridLayout
        ViewColumnGrid matlab.ui.container.GridLayout
        ViewGrid matlab.ui.container.GridLayout

        DatasetMenu matlab.ui.container.Menu
        RootFolderMenu matlab.ui.container.Menu
        MetadataMenu matlab.ui.container.Menu
        ClearMetadataMenu matlab.ui.container.Menu
        FilenamePatternMenu matlab.ui.container.Menu
        PublishedSheetMenu matlab.ui.container.Menu
        ClearPublishedSheetMenu matlab.ui.container.Menu
        SheetMenu matlab.ui.container.Menu
        SheetConfigureMenu matlab.ui.container.Menu
        SheetPrepareMenu matlab.ui.container.Menu
        SheetClearMenu matlab.ui.container.Menu
        LoadMenu matlab.ui.container.Menu
        ExportWorkspaceMenu matlab.ui.container.Menu

        DisplayMenu matlab.ui.container.Menu

        % One entry per Display menu item that mirrors a panel control, so
        % SYNCDISPLAYMENU can walk the menu without a handle property each.
        DisplayMirrors struct = struct([])

        ViewMenu matlab.ui.container.Menu
        DataColumnMenu matlab.ui.container.Menu
        DisplayRowMenu matlab.ui.container.Menu
        AllPanelsMenu matlab.ui.container.Menu

        HelpMenu matlab.ui.container.Menu
        ShortcutsMenu matlab.ui.container.Menu
        AtlasExplorerMenu matlab.ui.container.Menu
        ReportBugMenu matlab.ui.container.Menu
        RequestFeatureMenu matlab.ui.container.Menu

        TrackerLinkLabel matlab.ui.control.Hyperlink
        SearchField matlab.ui.control.EditField
        SubjectList matlab.ui.control.ListBox
        HemisphereList matlab.ui.control.ListBox
        StainList matlab.ui.control.ListBox
        PlateList matlab.ui.control.ListBox
        ProfileOnlyCheck matlab.ui.control.CheckBox
        SortDropDown matlab.ui.control.DropDown
        ResetFiltersButton matlab.ui.control.Button

        CatalogTable matlab.ui.control.Table
        CountLabel matlab.ui.control.Label
        PreviousButton matlab.ui.control.Button
        NextButton matlab.ui.control.Button
        SelectAllButton matlab.ui.control.Button
        ArrangeColumnsButton matlab.ui.control.Button

        VariantDropDown matlab.ui.control.DropDown
        ChannelDropDown matlab.ui.control.DropDown
        ColormapDropDown matlab.ui.control.DropDown
        LowPercentileField matlab.ui.control.NumericEditField
        HighPercentileField matlab.ui.control.NumericEditField
        MaxTilesField matlab.ui.control.NumericEditField

        BackgroundDropDown matlab.ui.control.DropDown

        ShowRoiCheck matlab.ui.control.CheckBox
        ShowBandCheck matlab.ui.control.CheckBox
        ShowBandGridCheck matlab.ui.control.CheckBox
        ColorByIntensityCheck matlab.ui.control.CheckBox
        ProfileLayoutDropDown matlab.ui.control.DropDown
        ProfileSizeField matlab.ui.control.NumericEditField
        ProfileNormDropDown matlab.ui.control.DropDown
        ProfileScopeDropDown matlab.ui.control.DropDown
        ProfileDistanceDropDown matlab.ui.control.DropDown

        RoiSelectDropDown matlab.ui.control.DropDown
        AddRoiButton matlab.ui.control.Button
        RoiNamesButton matlab.ui.control.Button
        RoiListLabel matlab.ui.control.Label

        EditRoiButton matlab.ui.control.StateButton
        RoiWidthField matlab.ui.control.NumericEditField
        DrawRoiButton matlab.ui.control.Button
        SaveRoiButton matlab.ui.control.Button
        RevertRoiButton matlab.ui.control.Button
        RoiEditLabel matlab.ui.control.Label

        ShowSurfaceCheck matlab.ui.control.CheckBox
        MarkSurfaceButton matlab.ui.control.Button
        DetectSurfaceButton matlab.ui.control.Button
        ClearSurfaceButton matlab.ui.control.Button
        SurfaceLabel matlab.ui.control.Label

        NewFigureButton matlab.ui.control.Button
        FijiButton matlab.ui.control.Button
        ExportButton matlab.ui.control.Button
        OpenFolderButton matlab.ui.control.Button

        StatusBar matlab.ui.container.Panel
        StatusLamp matlab.ui.control.Label
        StatusLabel matlab.ui.control.Label
        StatusDetail matlab.ui.control.Label

        ImagePanel matlab.ui.container.Panel
        ProfilePanel matlab.ui.container.Panel
        ImageLayout matlab.graphics.layout.TiledChartLayout
        ProfileAxes matlab.ui.control.UIAxes

        % One right-click menu for every tile and one for the profile axes,
        % both parented to the figure and handed out to each object drawn in a
        % plot. A menu per tile was the obvious alternative and was rejected:
        % twelve copies of the same twenty items would be built and thrown away
        % on every redraw, which is exactly the cost ONDISPLAYOPTIONCHANGED
        % now goes out of its way to avoid.
        TileContextMenu matlab.ui.container.ContextMenu
        ProfileContextMenu matlab.ui.container.ContextMenu
    end

    properties
        RootPath string = ""        % Folder scanned for images and values files.
        MetadataPath string = ""    % Optional section tracker CSV.

        % Named-capture pattern PARSE_HISTOLOGY_FILENAME reads names with, or
        % "" for the built-in convention. Empty by default, so an app nobody
        % has configured catalogs exactly as it always did.
        FilenamePattern string = ""

        % The tracker can come from three places, and ONLOADDATA reads them in
        % the order they are declared here: the Sheets API first, then the
        % published copy, then the CSV. The order runs from the most current
        % and most capable source to the one that asks least of the machine it
        % runs on, so a browser configured with several uses the best of them
        % and the others stay set as fallbacks rather than having to be cleared.

        % The tracker read from the Google Sheet it is maintained in rather
        % than from an export of it. What the browser shows is what the sheet
        % says now rather than what it said when somebody last exported, and
        % this is the only source REVIEW can write back to.
        SheetUrl string = ""        % Spreadsheet URL or ID.
        SheetTab string = "Sections"
        SheetCredentials string = "" % Service account JSON key file.
        Tracker = []                % SECTIONTRACKER once one has been built.

        % The same tracker, downloaded from the published copy of the sheet it
        % is maintained in rather than from an export somebody made by hand.
        % Used in place of the CSV when set, so a load picks up whatever the
        % sheet said the last time Google republished it. Needs no credentials,
        % and is read only.
        PublishedUrl string = ""

        % Fiji launcher ONOPENINFIJI starts, found or chosen on first use and
        % remembered, or "" until then.
        FijiPath string = ""


        Data struct = struct()      % Structured output from COMBINE_VALUES_CSV.
        Catalog table = table()     % One row per image stem.
        View table = table()        % Catalog rows passing the active filters.
        Selection double = []       % Row indices into View.

        % Catalog variables the Sections table shows, in the order it shows
        % them. Held as catalog variable names rather than as the headings
        % they are drawn under, because a heading is a label this code is free
        % to reword while a saved arrangement has to keep meaning the same
        % thing across releases.
        CatalogColumns string = HistologyImageBrowser.DefaultCatalogColumns

        % Column the Sections table is sorted on, as a catalog variable name,
        % and the direction it runs in. "" when no header sort is in force, in
        % which case the Sort by preset alone decides the order.
        CatalogSortColumn string = ""
        CatalogSortDirection string = "ascend"

        % Sort by preset the column sort was made under. The dropdown's own
        % callback belongs to BUILDFILTERPANEL and calls straight into
        % APPLYFILTERS, so that is where the preset moving is noticed, by
        % comparing it against this rather than by giving the dropdown a
        % callback of its own.
        CatalogSortPreset string = ""

        % True while WRITECATALOGTABLE is assigning the table's Data. The
        % assignment is what ONCATALOGDISPLAYCHANGED reacts to, so without this
        % the handler could answer its own write.
        CatalogTableSyncing logical = false
        ImageCache = []             % containers.Map of decoded display images.
        CacheOrder string = strings(0, 1)

        % Colormap last chosen for each stain, kept as parallel lists.
        % Selecting a section brings back the colormap its stain was last
        % shown in, so moving between stains does not mean setting it again.
        ColormapStains string = strings(0, 1)
        ColormapChoices string = strings(0, 1)

        % What each ROI key is called on screen, kept as parallel lists for
        % the same reason the colormaps are. A section's ROIs are keyed by the
        % letters A, B, C ... in the filenames of their .roi and values.csv
        % sidecars, and those letters say nothing about what was measured, so
        % a key can be given the region's own name -- A is ACx, B is S1 -- and
        % the overlay, the legend, and the catalog then use it. The names
        % belong to the study rather than to one sitting with the browser, so
        % they are kept between sessions. A key with no name here shows as
        % itself.
        RoiNameKeys string = strings(0, 1)
        RoiNameLabels string = strings(0, 1)

        % Color behind the image tiles. Set from the panel's own default when
        % the UI is built, so an untouched app looks exactly as it always did.
        ImageBackground double = [0.96 0.96 0.96]

        % True while the lookup and catalog column, or the display controls
        % above the tiles, are collapsed. The two hide independently, because
        % one sitting wants the filters out of the way and another wants the
        % display options out of the way. They are only resized, never rebuilt,
        % so everything in them survives being hidden.
        DataColumnHidden logical = false
        DisplayRowHidden logical = false

        % Settings the tiles now on screen were drawn from, as one string.
        % ONDISPLAYOPTIONCHANGED compares it against the settings in force to
        % tell a change of pixels from a change of overlay, because every
        % display control shares that one callback and none of them says which
        % one moved.
        RenderKey string = ""

        % Axes the last right-click landed on, so a context menu item can act
        % on the tile under the pointer rather than on the first selected row.
        ContextAxes = []

        StatusLevel string = "info" % Severity of the message now on the status bar.
        StatusHistory string = strings(0, 1)

        % Which of the selected section's ROIs the edit controls act on. The
        % key is kept rather than an index into the section's list, so
        % stepping through sections stays on the same region -- ACx after ACx
        % -- instead of landing on whichever ROI each section happens to list
        % first.
        ActiveRoiKey string = ""

        RoiEditStem string = ""     % Stem being edited; empty when idle.
        RoiEditKey string = ""      % Which ROI of that stem is being edited.

        % Section the ROI controls act on, chosen by clicking its tile. Empty
        % means nobody has chosen and the browser picks the first selected row,
        % which is what an untouched view does and what one whose target has
        % left the selection falls back to. ACTIVEROISTEM is the reader, and it
        % validates against what is on screen, so a stale stem here can never
        % point the buttons at a section nobody can see.
        %
        % Which section, only. Which of that section's ROIs is ACTIVEROIKEY,
        % chosen from the ROI dropdown rather than by clicking.
        RoiTargetStem string = ""
        RoiEditGeom struct = struct()   % Unsaved x1, y1, x2, y2, strokeWidth, name.
        RoiEditDirty logical = false    % True when the edit differs from the file.

        % True when the ROI had no files when this edit session opened. Such a
        % line is saved as soon as it is placed or drawn, so adding an ROI
        % creates its data without a separate Save.
        RoiEditCreated logical = false
        RoiPreview struct = struct()    % Profile measured from the unsaved geometry.
        RoiEditor = []              % images.roi.Line drawn on the edited tile.

        % images.roi.Point marking the brain surface on the edited line, and
        % true while it is the thing being dragged. The point is constrained to
        % the line rather than free in the image: a surface off the line has no
        % depth along the profile, which is the only thing the mark is for, so
        % ONSURFACEEDITCHANGED projects every position back onto it.
        SurfaceEditor = []
        SurfaceEditDragging logical = false

        % True between the first move of a drag and the mouse coming back up.
        % The shading under the band is measured data, and data measured from a
        % line that is still moving would be wrong, so it is left out until the
        % drag ends.
        RoiEditDragging logical = false

        % True while DRAWLINE or DRAWPOINT is waiting for the mouse. Both are
        % after a click on one particular tile, and a click that wandered onto
        % another one must not retarget the ROI controls in the middle of them:
        % that would close the very edit the line or mark is being placed into,
        % and could raise an unsaved-changes dialog underneath a placement that
        % is still running. ATTACHCONTEXTMENU's click handler is the reader.
        RoiPlacing logical = false

        % Stem and ROI written to disk in this session. They drive the green
        % "saved" aesthetic on the tile, which outlives the edit session so
        % leaving edit mode does not erase the confirmation, and is cleared as
        % soon as the selection moves on or the line is touched again. The key
        % is carried too, so a section holding several ROIs marks the one that
        % was actually written rather than all of them.
        RoiSavedStem string = ""
        RoiSavedKey string = ""

        MeasureImage = []           % Full resolution page profiles are measured from.
        MeasureKey string = ""      % Image path the cached page came from.
        MeasurePixelSize double = NaN
        MeasurePixelSizeSource string = ""
    end

    properties (Constant)
        PrefGroup = "HistologyImageBrowser"
        MaxCachedImages = 40
        MaxDisplayEdge = 1400       % Longest displayed edge, in pixels.
        DefaultRoiWidth = 994       % Sampling band width for a new line, in pixels.
        MaxStatusHistory = 15       % Messages kept in the status bar tooltip.
        BrowseColumnWidth = 460     % Width of the lookup and catalog column, in pixels.

        % The built-in naming convention written out as a pattern, offered by
        % ONEDITFILENAMEPATTERN as the starting point for editing rather than
        % used to parse anything: an empty FilenamePattern runs the convention
        % directly, which is the only way to keep an unconfigured app parsing
        % byte-for-byte as it did before patterns existed. Everything the
        % convention extracts is here except the split of SampleID into
        % Protocol and Series, which no single flat pattern expresses without
        % becoming unreadable to the person meant to edit it.
        DefaultFilenamePattern = "^(?<SubjectID>SUBJ-ID-\d+)(?<SampleID>.*)_(?<SectionID>[^_]+)_(?<Hemisphere>[^_]+)_(?<Stain>[^_]+)_(?<ZPlane>[^_]+)_(?<DateCode>[^_]+)_(?<ImageNumber>[^_]+)$"

        % Filenames the pattern dialog previews against. The table is rebuilt on
        % every keystroke, so the head of a large catalog stands in for it and
        % the count is reported beside the table.
        MaxPatternPreviewNames = 200

        % Keys the naming dialog always offers, whether or not a section uses
        % them yet, so the regions a study measures can be named once at the
        % start rather than one at a time as each is first drawn. Any further
        % key a dataset turns out to hold is offered alongside them.
        DefaultRoiKeys = ["A", "B", "C", "D", "E", "F"]

        % Status severities, and the lamp glyph each one shows.
        StatusLevels = ["info", "busy", "success", "warning", "error"]
        StatusGlyphs = string(char([9679; 9680; 9679; 9650; 9632]))

        % Placement choices for the profile plot, and their stored codes.
        ProfileLayoutNames = ["Below images", "Above images", "Left of images", "Right of images", "Hidden", "Profiles only"]
        ProfileLayoutCodes = ["bottom", "top", "left", "right", "hidden", "only"]

        % Normalizations the profile plot can put the intensity axis through,
        % their stored codes, and what the axis is called under each. Three
        % parallel arrays rather than a struct array, matching how the
        % background and layout choices beside them are already written.
        %
        % These change the picture and never the data: NORMALIZEPROFILES works
        % on the copy RENDERPROFILEPLOT is about to draw, so the values files,
        % a remeasured ROI, and everything ONEXPORTWORKSPACE hands out stay in
        % the units they were measured in whatever is chosen here.
        ProfileNormNames = ["Raw intensity", "Baseline subtracted", "Min-max (0-1)", ...
            "Percent of max", "Fold of mean", "Z-score"]
        ProfileNormCodes = ["none", "baseline", "range", "max", "mean", "zscore"]
        ProfileNormLabels = ["intensity", "intensity above baseline", ...
            "normalized intensity (0-1)", "intensity (% of max)", ...
            "intensity (fold of mean)", "intensity (z-score)"]

        % Whether the numbers a normalization subtracts and divides by are
        % taken from the one trace being scaled or from every trace on the
        % plot. Scaling each trace by itself puts sections of very different
        % brightness on one scale and throws away how they differed; scaling
        % them all by one set of numbers keeps that difference, which is what
        % is wanted whenever the sections are meant to be compared to each
        % other rather than each read for its own shape.
        ProfileScopeNames = ["Each trace", "All traces"]
        ProfileScopeCodes = ["each", "all"]

        % The same for the distance axis, which is normalized per trace
        % whatever the scope says: a line's own start and its own length are
        % the only things "from line start" and "percent of line" can mean.
        %
        % "From brain surface" is the one that needs a mark to mean anything.
        % A trace whose section has none falls back to its own line start,
        % which is what the distance axis already meant for it, and
        % RENDERPROFILEPLOT says how many did -- so an unmarked section reads
        % as unaligned rather than as aligned at a surface nobody found.
        ProfileDistanceNames = ["As measured", "From line start", ...
            "Percent of line", "From brain surface"]
        ProfileDistanceCodes = ["none", "start", "percent", "surface"]
        ProfileDistanceLabels = ["distance along line (\mum)", ...
            "distance from line start (\mum)", "distance along line (% of length)", ...
            "depth from brain surface (\mum)"]

        % Background presets for the image panel, and their stored codes.
        % Light gray is the shade a uipanel uses by default, so an untouched
        % app opens on a named preset rather than reading as a custom color.
        BackgroundNames = ["White", "Light gray", "Mid gray", "Charcoal", "Black"]
        BackgroundCodes = ["white", "lightgray", "midgray", "charcoal", "black"]
        BackgroundColors = [1 1 1; 0.96 0.96 0.96; 0.50 0.50 0.50; 0.15 0.15 0.15; 0 0 0]

        % Two further entries the background list carries beyond the presets:
        % the item that opens the picker, and the one naming a color that came
        % back from it. They are codes only; their text is built where needed.
        PickBackgroundCode = "pick"
        CustomBackgroundCode = "custom"

        % Where the Help menu points. The atlas is a companion tool rather than
        % part of this app, and the tracker is where its issues are raised, so
        % both are addresses rather than anything this window renders itself.
        % The browser lives in histology_analysis, so its issues go there.
        AtlasExplorerURL = "https://dstolz.github.io/GerbilAtlasExplorer/gerbil_atlas_explorer.html"
        RepositoryURL = "https://github.com/dstolz/histology_analysis"

        % Longest new-issue link worth handing to a browser. Browsers and the
        % Windows shell both stop accepting a URL somewhere above this, and
        % they truncate rather than refuse, so a longer report is opened as an
        % empty form and pasted from the clipboard instead of being cut in half.
        MaxIssueUrlLength = 8000

        % Columns the Sections table can be made to show: the catalog variable
        % each one reads, the heading it is drawn under, and the width it is
        % drawn at. Three parallel arrays rather than a struct array, matching
        % how the background and profile-layout choices are already written,
        % because the three read across in one glance here and a struct array
        % would put each column on five lines of its own.
        %
        % The list is a curated subset of the catalog rather than all of it.
        % ValuesPaths and ROILabels hold a string array per row, which a table
        % cell cannot draw at all, and the four rendition paths say nothing the
        % Images column does not already say more briefly. Widths are text so
        % that one array can carry both a pixel count and the keyword that lets
        % a column take whatever is left.
        CatalogColumnFields = ["SubjectID", "SectionID", "Hemisphere", "Stain", ...
            "AtlasPlate", "NProfiles", "Variants", "Status", "Stem", "SampleID", ...
            "Protocol", "Series", "ZPlane", "DateCode", "ImageNumber", "ROI", ...
            "NVariants", "NameParsed", "InTracker", "Measured", "Content", ...
            "Slide", "SliceID", "ImageDate", "LaserPower", "Notes", ...
            "ProcessingID", "Folder"]
        CatalogColumnHeadings = ["Subject", "Section", "Hemi", "Stain", ...
            "Plate", "Prof", "Images", "Status", "Stem", "Sample", ...
            "Protocol", "Series", "ZPlane", "Date", "ImageNum", "ROI", ...
            "NImages", "Parsed", "Tracked", "Meas", "Content", ...
            "Slide", "Slice", "Acquired", "Laser", "Notes", ...
            "Processing", "Folder"]
        CatalogColumnWidths = ["70", "60", "45", "70", ...
            "45", "40", "auto", "auto", "220", "70", ...
            "70", "55", "55", "70", "60", "90", ...
            "45", "50", "55", "40", "90", ...
            "50", "55", "80", "55", "auto", ...
            "80", "240"]

        % The arrangement an app nobody has configured opens with: the eight
        % columns the table showed before it could be rearranged, plus ROI.
        %
        % ROI is the one addition. A section can carry several lines now, one
        % per region measured across it, and which regions those are is the
        % first thing anyone working through a stack needs to see; leaving it
        % out would have hidden the whole point of the ROI keys behind Arrange
        % Columns. NProfiles stays beside it rather than being replaced by it:
        % the two disagree whenever a line has been drawn but not yet measured,
        % and that gap is worth seeing.
        DefaultCatalogColumns = ["SubjectID", "SectionID", "Hemisphere", "Stain", ...
            "AtlasPlate", "NProfiles", "ROI", "Variants", "Status"]

        % Catalog columns the section tracker is the only source of. Named
        % when a load has to go ahead without the tracker, so what came up
        % blank is said once rather than discovered a column at a time.
        TrackerColumns = ["AtlasPlate", "Content", "Slide", "SliceID", ...
            "ImageDate", "LaserPower", "Notes", "ProcessingID"]

        % Variable the display table carries each row's section stem in, drawn
        % at zero width. It is what maps a displayed row back to a catalog row
        % after the user sorts, so it is present in every arrangement whether
        % or not the visible Stem column is.
        CatalogKeyColumn = "SectionStem"
    end

    methods
        function obj = HistologyImageBrowser(rootPath, options)
            % Construct the browser, optionally loading a dataset immediately.

            arguments
                rootPath (1,1) string = ""
                options.metadataCSV (1,1) string = ""
                options.publishedUrl (1,1) string = ""
                options.sheetUrl (1,1) string = ""
                options.sheetTab (1,1) string = ""
                options.sheetCredentials (1,1) string = ""
            end

            obj.ImageCache = containers.Map("KeyType", "char", "ValueType", "any");
            obj.RootPath = string(pwd);

            obj.buildUI();
            obj.loadPreferences();
            obj.updateRoiEditControls();

            if rootPath ~= ""
                obj.RootPath = rootPath;
            end

            if options.metadataCSV ~= ""
                obj.MetadataPath = options.metadataCSV;
            end

            % Named on the call rather than restored from preferences, so a
            % script can point one session at a different sheet without
            % changing what the next one opens on.
            if options.publishedUrl ~= ""
                obj.PublishedUrl = options.publishedUrl;
            end

            if options.sheetUrl ~= ""
                obj.SheetUrl = options.sheetUrl;
                obj.Tracker = [];
            end

            if options.sheetTab ~= ""
                obj.SheetTab = options.sheetTab;
                obj.Tracker = [];
            end

            if options.sheetCredentials ~= ""
                obj.SheetCredentials = options.sheetCredentials;
                obj.Tracker = [];
            end

            obj.refreshDatasetMenu();

            if rootPath ~= ""
                obj.onLoadData();
            end

            if nargout == 0
                clear obj
            end
        end

        buildUI(obj)                    % Build the figure and all panels.

        buildDatasetMenu(obj)           % Build the Dataset menu on the menu bar.

        buildDisplayMenu(obj, parent)   % Mirror the Display panel onto a menu.

        syncDisplayMenu(obj)            % Make that menu agree with the panel.

        promptDisplayNumber(obj, index) % Ask for a numeric display setting.

        buildViewMenu(obj)              % Build the View menu on the menu bar.

        buildHelpMenu(obj)              % Build the Help menu on the menu bar.

        buildFilterPanel(obj, parent)   % Build the lookup and filter controls.

        buildCatalogTable(obj, parent)  % Build the results table and navigation.

        buildDisplayPanel(obj, parent)  % Build the display and overlay controls.

        buildViewPanel(obj, parent)     % Build the image tiles and profile axes.

        buildStatusBar(obj, parent)     % Build the status strip along the bottom.

        applyViewLayout(obj)            % Place the image and profile panels per the layout choice.

        onLoadData(obj)                 % Run COMBINE_VALUES_CSV and build the catalog.

        onConfigureSheet(obj)           % Point the browser at a Google Sheet tracker.

        onPrepareSheet(obj)             % Add the columns a review write needs.

        onEditFilenamePattern(obj)      % Edit the filename pattern, with a live preview.

        tf = applyFilenamePattern(obj, pattern, options)  % Adopt a filename pattern.

        [names, source] = filenamePatternSamples(obj)     % Names the preview runs on.

        refreshFilterChoices(obj)       % Repopulate filter lists from the catalog.

        applyFilters(obj)               % Filter the catalog and refresh the table.

        refreshCatalogTable(obj)        % Push the filtered view into the table.

        writeCatalogTable(obj)          % Put the view into the table widget, row for row.

        onCatalogDisplayChanged(obj)    % Follow a header sort by reordering the view.

        applyCatalogColumns(obj, columns, options)  % Adopt a column arrangement.

        onArrangeColumns(obj)           % Choose which columns show, and in what order.

        refreshReviewColumns(obj)       % Rewrite just the review columns, in place.

        onSelectionChanged(obj)         % Handle a table selection change.

        target = reviewTarget(obj)      % Tracker rows a review write would reach.

        onSetMeasured(obj, measured)    % Mark or unmark the selection as measured.

        ok = writeReview(obj, uids, updates, description)  % Send one review edit to the tracker.

        renderSelection(obj)            % Draw the selected images and profiles.

        drawImageTile(obj, ax, row, tileColor, isActive)  % Draw one image with its overlay.

        drawRoiOverlay(obj, ax, row, tileColor) % Draw every line ROI and sampling band.

        refreshOverlays(obj)            % Redraw every tile's overlay, keeping the images.

        refreshTileOverlay(obj, ax)     % Redraw one tile's overlay, keeping its image.

        buildPlotContextMenus(obj)      % Build the right-click menus for the plots.

        attachContextMenu(obj, ax, kind)  % Give an axes and its contents a right-click menu.

        renderProfilePlot(obj)          % Draw profiles for the current selection.

        updateProfileControls(obj)      % Enable the profile options that apply now.

        [img, imageSize, reason] = loadDisplayImage(obj, imagePath, page)  % Load and cache one image.

        P = readProfile(obj, row, key)  % Read one ROI's profile for a catalog row.

        R = roiForRow(obj, row, key)    % One line ROI of a row, edited or on disk.

        geometry = initialRoiGeometry(obj, row, key)  % Geometry an edit session starts from.

        onAddRoi(obj)                   % Start a new ROI on the selected section.

        onRoiSelectionChanged(obj)      % Take a new active ROI from the dropdown.

        syncRoiSelector(obj)            % Offer the selected section's ROIs.

        onEditRoiNames(obj)             % Rename the ROI keys A, B, C ...

        onToggleEditRoi(obj, key)       % Enter or leave ROI editing.

        targeted = setRoiTarget(obj, stem)  % Point the ROI controls at one drawn tile.

        markRoiTarget(obj)              % Move the ROI target mark to the right tile.

        proceed = exitRoiEdit(obj, askWhenDirty) % Leave editing, offering to save first.

        attachRoiEditor(obj, ax, row)   % Put the draggable line on the edited tile.

        applyRoiEditorStyle(obj)        % Recolor the draggable line for the current state.

        onRoiEditChanged(obj, position, isFinal) % Take a new position from the drag.

        onRoiWidthChanged(obj)          % Apply a new sampling band width.

        onDrawRoi(obj)                  % Draw a new line ROI on the image.

        onMarkSurface(obj)              % Click on the image to place the surface mark.

        onDetectSurface(obj)            % Find the surface from the profile, and mark it.

        onClearSurface(obj)             % Take the surface mark off the edited line.

        found = detectSurface(obj, options)  % Locate the surface under the edited line.

        attachSurfaceEditor(obj, ax, row)    % Put the draggable surface mark on the tile.

        onSurfaceEditChanged(obj, position, isFinal)  % Take a dragged surface position.

        imagePath = measureImagePath(obj, row)  % Image a profile is measured from.

        refreshRoiOverlay(obj)          % Redraw just the edited tile's overlay.

        refreshRoiEdit(obj, stem)       % Redraw what an ROI edit changed, and nothing else.

        updateRoiPreview(obj)           % Remeasure the profile under the unsaved ROI.

        M = loadMeasureImage(obj, row)  % Load the page profiles are measured from.

        onSaveRoiEdits(obj)             % Write the ROI and its profile back to disk.

        onRevertRoiEdits(obj)           % Go back to the ROI on disk.

        updateRoiEditControls(obj)      % Enable the ROI controls that apply now.

        imagePath = resolveImagePath(obj, row)  % Resolve the selected rendition path.

        rows = selectedRows(obj)        % Return the catalog rows currently selected.

        onExportView(obj)               % Export the current view to an image file.

        onExportWorkspace(obj, variableName)  % Export the selection to a base workspace table.

        onOpenInFigure(obj)             % Redraw the current selection in a normal figure.

        onOpenInFiji(obj)               % Open the marked section's image and ROIs in Fiji.

        loadPreferences(obj)            % Restore saved paths and display settings.

        savePreferences(obj)            % Persist paths and display settings.

        onFigureKeyPress(obj, evt)      % Match a key press to a shortcut.

        runShortcut(obj, action)        % Carry out one named shortcut.

        onShowShortcuts(obj)            % List every shortcut in a dialog.

        onReportIssue(obj, kind)        % Open a prefilled bug or feature issue.

        [title, body] = issueTemplate(obj, kind)  % Compose one issue's title and body.

        text = diagnosticsReport(obj)   % Describe the build, machine, and settings.

        function onCloseRequest(obj)
            % Record where the window sits, then close it.
            % Preferences are written from here rather than from a destructor
            % so the geometry is read while the window is still on screen. A
            % failure to write them must not leave a window that will not
            % close, so the save is allowed to fail quietly.

            try
                obj.savePreferences();
            catch
            end

            delete(obj.Fig);
        end

        function onBrowseRoot(obj)
            % Prompt for the histology root folder.
            startDir = obj.RootPath;

            if startDir == "" || ~isfolder(startDir)
                startDir = string(pwd);
            end

            selected = uigetdir(startDir, "Select histology root folder");

            if isequal(selected, 0)
                return
            end

            obj.RootPath = string(selected);
            obj.refreshDatasetMenu();
            obj.savePreferences();
            obj.setStatus("Root folder set to %s. Choose Dataset > Load Dataset.", obj.RootPath);
        end

        function onBrowseMetadata(obj)
            % Prompt for the section tracker CSV.
            [f, p] = uigetfile("*.csv", "Select section tracker CSV");

            if isequal(f, 0)
                return
            end

            obj.MetadataPath = string(fullfile(p, f));
            obj.refreshDatasetMenu();
            obj.savePreferences();
            obj.setStatus("Tracker CSV set to %s. Load again to apply it.", obj.MetadataPath);
        end

        function onClearMetadata(obj)
            % Drop the tracker CSV so the next load runs without annotations.
            if obj.MetadataPath == ""
                return
            end

            obj.MetadataPath = "";
            obj.refreshDatasetMenu();
            obj.savePreferences();
            obj.setStatus("Tracker CSV cleared. Load again to drop its annotations.");
        end

        function onSetPublishedSheet(obj)
            % Ask for the published sheet URL and check it before accepting it.
            % Everything that can be wrong with one of these -- an edit link
            % pasted instead of a published link, a tab that was unpublished,
            % the wrong tab -- looks the same from here until something tries
            % to read it, so it is read now rather than at the next load.

            answer = inputdlg( ...
                {sprintf(['Published sheet URL:\n\n' ...
                    'In the sheet: File > Share > Publish to web,\n' ...
                    'pick the Sections tab and the CSV format.'])}, ...
                "Published Sheet Tracker", [1 90], cellstr(obj.PublishedUrl));

            if isempty(answer)
                return
            end

            url = strtrim(string(answer{1}));

            if url == ""
                obj.onClearPublishedSheet();
                return
            end

            obj.setBusy("Reading the published sheet ...");

            try
                csvPath = fetch_published_tracker(url);
                cleanup = onCleanup(@() delete(csvPath));
            catch ME
                obj.setError("The published sheet was not accepted: %s", ME.message);
                uialert(obj.Fig, ME.message, "Sheet Not Read");
                return
            end

            obj.PublishedUrl = url;
            obj.refreshDatasetMenu();
            obj.savePreferences();
            obj.setSuccess("Published sheet set. Load again to apply it.");
        end

        function onClearPublishedSheet(obj)
            % Stop reading the tracker from the sheet.
            if obj.PublishedUrl == ""
                return
            end

            obj.PublishedUrl = "";
            obj.refreshDatasetMenu();
            obj.savePreferences();
            obj.setStatus("Published sheet cleared. Load again to drop its annotations.");
        end

        function onClearSheet(obj)
            % Stop reading the tracker from the sheet, without touching it.
            if obj.SheetUrl == ""
                return
            end

            obj.SheetUrl = "";
            obj.Tracker = [];
            obj.refreshDatasetMenu();
            obj.savePreferences();
            obj.setStatus("Sheet tracker cleared. The sheet itself was not changed.");
        end

        function tracker = sheetTracker(obj)
            % The tracker object for the configured sheet, built on demand.
            % Held between loads so a sitting spends one token request rather
            % than one per read.

            if obj.SheetUrl == ""
                tracker = [];
                return
            end

            needsNew = isempty(obj.Tracker) || ~isvalid(obj.Tracker) ...
                || obj.Tracker.SpreadsheetId ~= gsheet.spreadsheetId(obj.SheetUrl) ...
                || obj.Tracker.SheetName ~= obj.SheetTab ...
                || obj.Tracker.CredentialsPath ~= obj.SheetCredentials;

            if needsNew
                obj.Tracker = SectionTracker(obj.SheetUrl, obj.SheetCredentials, ...
                    sheetName = obj.SheetTab);
            end

            tracker = obj.Tracker;
        end

        function refreshDatasetMenu(obj)
            % Show the current selections on the Dataset menu and in the title.
            % The paths used to sit in edit fields, so the menu labels and the
            % window title are now the only place they are visible.

            if isempty(obj.RootFolderMenu) || ~isvalid(obj.RootFolderMenu)
                return
            end

            obj.RootFolderMenu.Text = "Root Folder:  " ...
                + HistologyImageBrowser.menuPathLabel(obj.RootPath, "none selected");
            obj.MetadataMenu.Text = "Tracker CSV:  " ...
                + HistologyImageBrowser.menuPathLabel(obj.MetadataPath, "none");

            if obj.MetadataPath == ""
                obj.ClearMetadataMenu.Enable = "off";
            else
                obj.ClearMetadataMenu.Enable = "on";
            end

            obj.PublishedSheetMenu.Text = "Published Sheet:  " ...
                + HistologyImageBrowser.publishedSheetLabel(obj.PublishedUrl);
            obj.ClearPublishedSheetMenu.Enable = ...
                matlab.lang.OnOffSwitchState(obj.PublishedUrl ~= "");

            obj.refreshSheetMenu();

            obj.refreshTrackerLink();

            if obj.RootPath == ""
                obj.Fig.Name = "Histology Image Browser";
            else
                obj.Fig.Name = "Histology Image Browser  -  " + obj.RootPath;
            end
        end

        function refreshTrackerLink(obj)
            % Show, above the search field, a link to whichever tracker source
            % is in play: the sheet read over the API first, then the published
            % copy, then a local CSV, matching the order ONLOADDATA reads them
            % in. Hidden when none is set, since there is nothing to link to.

            if isempty(obj.TrackerLinkLabel) || ~isvalid(obj.TrackerLinkLabel)
                return
            end

            if obj.SheetUrl ~= ""
                obj.TrackerLinkLabel.Text = "Tracker: Google Sheet, " ...
                    + obj.SheetTab + " tab";
                obj.TrackerLinkLabel.Tooltip = "Open the sheet in your browser.";
                obj.TrackerLinkLabel.Visible = "on";
            elseif obj.PublishedUrl ~= ""
                obj.TrackerLinkLabel.Text = "Tracker: published sheet " ...
                    + HistologyImageBrowser.publishedSheetLabel(obj.PublishedUrl);
                obj.TrackerLinkLabel.Tooltip = "Open the published sheet in your browser.";
                obj.TrackerLinkLabel.Visible = "on";
            elseif obj.MetadataPath ~= ""
                obj.TrackerLinkLabel.Text = "Tracker: " ...
                    + HistologyImageBrowser.menuPathLabel(obj.MetadataPath, "none");
                obj.TrackerLinkLabel.Tooltip = "Open the tracker CSV: " + obj.MetadataPath;
                obj.TrackerLinkLabel.Visible = "on";
            else
                obj.TrackerLinkLabel.Text = "";
                obj.TrackerLinkLabel.Visible = "off";
            end
        end

        function onOpenTrackerLink(obj)
            % Open whichever tracker source the link above the search field is
            % currently showing: either sheet in a browser, or the local tracker
            % CSV in whatever application handles CSVs.
            %
            % The order matches REFRESHTRACKERLINK, which in turn matches the
            % one ONLOADDATA reads them in, so the link always opens the source
            % the catalog on screen was actually annotated from.

            if obj.SheetUrl ~= ""
                obj.openExternalLink(obj.sheetEditUrl(), "the tracker sheet");
                return
            end

            if obj.PublishedUrl ~= ""
                obj.openExternalLink(obj.PublishedUrl, "the published sheet");
                return
            end

            if obj.MetadataPath == ""
                return
            end

            if ~isfile(obj.MetadataPath)
                obj.setError("Tracker CSV does not exist: %s", obj.MetadataPath);
                uialert(obj.Fig, "The tracker CSV does not exist: " + obj.MetadataPath, ...
                    "Invalid Tracker CSV");
                return
            end

            if ispc
                winopen(obj.MetadataPath);
            elseif ismac
                system("open """ + obj.MetadataPath + """ &");
            else
                system("xdg-open """ + obj.MetadataPath + """ &");
            end
        end

        function url = sheetEditUrl(obj)
            % A browsable address for the configured sheet. SheetUrl accepts a
            % bare spreadsheet ID as well as a pasted edit URL, and an ID on its
            % own is not something a browser can open, so one is built back up
            % into the canonical address. A reference neither form recognizes is
            % handed over as typed rather than refused here, which leaves the
            % browser to report it.

            url = strtrim(obj.SheetUrl);

            if startsWith(lower(url), "http")
                return
            end

            try
                url = "https://docs.google.com/spreadsheets/d/" ...
                    + gsheet.spreadsheetId(url) + "/edit";
            catch
            end
        end

        function refreshSheetMenu(obj)
            % Label the sheet submenu with what it is pointed at, and offer the
            % actions that only mean something once it is.

            if isempty(obj.SheetMenu) || ~isvalid(obj.SheetMenu)
                return
            end

            configured = obj.SheetUrl ~= "";

            if configured
                obj.SheetMenu.Text = "Google Sheet Tracker:  " + obj.SheetTab;
            else
                obj.SheetMenu.Text = "Google Sheet Tracker:  (none)";
            end

            % Preparing the sheet writes to it, which needs a key file even
            % though naming the spreadsheet does not.
            readyToWrite = configured && obj.SheetCredentials ~= "";

            obj.SheetPrepareMenu.Enable = matlab.lang.OnOffSwitchState(readyToWrite);
            obj.SheetClearMenu.Enable = matlab.lang.OnOffSwitchState(configured);
        end

        function onResetFilters(obj)
            % Clear every filter and show the whole catalog.
            obj.SearchField.Value = "";
            obj.SubjectList.Value = {};
            obj.HemisphereList.Value = {};
            obj.StainList.Value = {};
            obj.PlateList.Value = {};
            obj.ProfileOnlyCheck.Value = false;
            obj.SortDropDown.Value = "section";

            % A header sort is an ordering the user asked for just as the
            % filters are, so Reset clears it too. APPLYFILTERS would only
            % notice the preset moving, which it has not when the preset was
            % already "section".
            obj.CatalogSortColumn = "";

            obj.applyFilters();
        end

        function onStepSelection(obj, step)
            % Move the selection one row up or down for quick browsing.
            if height(obj.View) == 0
                return
            end

            if isempty(obj.Selection)
                nextRow = 1;
            else
                nextRow = min(max(obj.Selection(1) + step, 1), height(obj.View));
            end

            obj.CatalogTable.Selection = nextRow;
            obj.onSelectionChanged();
        end

        function onSelectAll(obj)
            % Select every row currently passing the filters.
            if height(obj.View) == 0
                return
            end

            % Row selections must be given as a row vector.
            obj.CatalogTable.Selection = 1:height(obj.View);
            obj.onSelectionChanged();
        end

        function onDisplayOptionChanged(obj)
            % Redraw after a display or overlay option changes, as cheaply as
            % that particular change allows.
            %
            % RENDERSELECTION tears the tiled layout down and builds it again,
            % which rereads every image and restretches every pixel. A new
            % variant, channel, colormap, contrast, tile cap, or background is
            % worth that; switching the sampling band on is not, because the
            % pictures and the axes are unchanged and only the overlay
            % graphics differ.
            %
            % Which one happened is worked out by comparing the settings that
            % decide the pixels against the ones the tiles were last drawn
            % from, rather than by giving each control a callback of its own.
            % Every route into this function -- the Display panel, the Display
            % menu, the context menus, and the keyboard shortcuts -- would have
            % had to be taught the split, and the state comparison cannot be
            % bypassed by a caller that forgets.

            obj.savePreferences();
            obj.syncDisplayMenu();

            if obj.displayRenderKey() == obj.RenderKey
                obj.refreshOverlays();
                return
            end

            obj.renderSelection();
        end

        function key = displayRenderKey(obj)
            % Summarize everything the drawn pixels depend on as one string.
            %
            % The selection is part of it because the tiles are drawn from it,
            % and the tile cap is part of it because it decides how many of
            % them there are. The profile layout is deliberately left out: it
            % is handled by ONLAYOUTOPTIONCHANGED, which already redraws the
            % tiles whenever a layout change has to bring them back, and
            % including it would make every band toggle after a resize of the
            % profile split pay for a full redraw it does not need.

            % The channel dropdown reports a number for a page and the text
            % "merge" for the composite, a dropdown with no ItemsData reports
            % a char row, and the background is a triplet, so every value is
            % converted to string first and only then laid out flat. Indexing
            % the raw value instead would take a char row apart letter by
            % letter, which still compares correctly but reads as nonsense the
            % first time anyone prints the key while debugging.
            settings = { ...
                obj.VariantDropDown.Value, ...
                obj.ChannelDropDown.Value, ...
                obj.ColormapDropDown.Value, ...
                obj.LowPercentileField.Value, ...
                obj.HighPercentileField.Value, ...
                obj.MaxTilesField.Value, ...
                obj.ImageBackground};

            parts = strings(1, numel(settings) + 1);

            for iSetting = 1:numel(settings)
                value = string(settings{iSetting});
                parts(iSetting) = join(value(:)', ",");
            end

            rows = obj.selectedRows();

            if height(rows) > 0
                parts(end) = join(string(rows.Stem), ",");
            end

            key = join(parts, "|");
        end

        function chooseFromMenu(obj, control, value)
            % Take a choice made on the Display menu.
            %
            % The panel control is written first and then asked to run its own
            % callback, so choosing from the menu and choosing from the panel
            % are the same act. Nothing here knows which callback belongs to
            % which control, which is what keeps the two from drifting apart.

            control.Value = value;

            callback = control.ValueChangedFcn;

            if isempty(callback)
                obj.syncDisplayMenu();
                return
            end

            % The callbacks all end in a sync of their own, so the menu is
            % already up to date by the time this returns.
            callback(control, []);
        end

        function onColormapChanged(obj)
            % Take a new colormap and tie it to the stain now on screen.
            obj.rememberStainColormap();
            obj.onDisplayOptionChanged();
        end

        function onImageBackgroundChanged(obj)
            % Take a background preset, or open the picker for any other color.
            code = string(obj.BackgroundDropDown.Value);

            if code == HistologyImageBrowser.PickBackgroundCode
                obj.pickImageBackground();
                return
            end

            % The entry naming the custom color already in use is there to be
            % read rather than chosen, and selecting it changes nothing.
            if code == HistologyImageBrowser.CustomBackgroundCode
                return
            end

            obj.setImageBackground(HistologyImageBrowser.backgroundColor(code));
        end

        function pickImageBackground(obj)
            % Choose any background color from the system color picker.
            % Cancelling leaves the current color alone, so the dropdown is put
            % back to what it said before the picker opened.

            try
                picked = uisetcolor(obj.ImageBackground, "Image Panel Background");
            catch ME
                obj.setError("Color picker failed: %s", ME.message);
                obj.syncBackgroundControls();
                return
            end

            if ~isnumeric(picked) || numel(picked) ~= 3
                obj.syncBackgroundControls();
                return
            end

            obj.setImageBackground(picked);
        end

        function setImageBackground(obj, color)
            % Apply a new background color and remember it for next time.
            obj.ImageBackground = min(max(double(color(:)'), 0), 1);
            obj.applyImageBackground();

            % Tiles carry the color themselves, and the text drawn on a blank
            % tile is picked to stay legible against it, so the redraw is what
            % actually makes a dark background readable.
            obj.onDisplayOptionChanged();
        end

        function applyImageBackground(obj)
            % Push the chosen color onto the panel and every tile already drawn.

            if isempty(obj.ImagePanel) || ~isvalid(obj.ImagePanel)
                return
            end

            obj.ImagePanel.BackgroundColor = obj.ImageBackground;

            % The panel title sits on that same color, so it has to move with
            % it or it disappears into a dark background.
            obj.ImagePanel.ForegroundColor = obj.tileTextColor();

            obj.syncBackgroundControls();

            if isempty(obj.ImageLayout) || ~isvalid(obj.ImageLayout)
                return
            end

            tiles = findall(obj.ImageLayout, "Type", "axes");

            for iTile = 1:numel(tiles)
                tiles(iTile).Color = obj.ImageBackground;
            end
        end

        function onToggleDataColumn(obj)
            % Flip the lookup and catalog column in or out of view.
            obj.DataColumnHidden = ~obj.DataColumnHidden;
            obj.applyPanelVisibility();
            obj.reportPanelVisibility("Data column", obj.DataColumnHidden, "toggleDataColumn");
        end

        function onToggleDisplayRow(obj)
            % Flip the display and overlay controls above the tiles in or out
            % of view.
            obj.DisplayRowHidden = ~obj.DisplayRowHidden;
            obj.applyPanelVisibility();
            obj.reportPanelVisibility("Display row", obj.DisplayRowHidden, "toggleDisplayRow");
        end

        function onToggleAllPanels(obj)
            % Give the image tiles the whole window, or put everything back.
            % Anything still on screen means the next press hides, so one key
            % always clears the window whatever was hidden piecemeal before it.
            hide = ~obj.DataColumnHidden || ~obj.DisplayRowHidden;

            obj.DataColumnHidden = hide;
            obj.DisplayRowHidden = hide;
            obj.applyPanelVisibility();
            obj.reportPanelVisibility("Data column and display row", hide, "toggleAllPanels");
        end

        function reportPanelVisibility(obj, name, hidden, action)
            % Say what a toggle just did, and name the key that undoes it.
            % The panels are off screen exactly when this matters, so the
            % status bar is the only place left to say it.

            if ~hidden
                obj.setStatus("%s shown.", name);
                return
            end

            key = strtrim(erase(HistologyImageBrowser.shortcutHint(action), ["(", ")"]));

            if key == ""
                obj.setStatus("%s hidden. The View menu brings it back.", name);
            else
                obj.setStatus("%s hidden. %s, or the View menu, brings it back.", name, key);
            end
        end

        function applyPanelVisibility(obj)
            % Collapse the browse column and the display row to nothing, or
            % give them their room back. Only the grid tracks change size; the
            % panels and every control in them stay built, so hiding them costs
            % nothing to undo and loses no filter, selection, or setting.

            if obj.DataColumnHidden
                obj.ContentGrid.ColumnWidth = {0, "1x"};
                obj.ContentGrid.ColumnSpacing = 0;
            else
                obj.ContentGrid.ColumnWidth = {obj.BrowseColumnWidth, "1x"};
                obj.ContentGrid.ColumnSpacing = 8;
            end

            if obj.DisplayRowHidden
                obj.ViewColumnGrid.RowHeight = {0, "1x"};
                obj.ViewColumnGrid.RowSpacing = 0;
            else
                obj.ViewColumnGrid.RowHeight = {"fit", "1x"};
                obj.ViewColumnGrid.RowSpacing = 6;
            end

            % A check reads as "this is on screen now", so the marks follow
            % what is shown rather than what is hidden.
            obj.DataColumnMenu.Checked = matlab.lang.OnOffSwitchState(~obj.DataColumnHidden);
            obj.DisplayRowMenu.Checked = matlab.lang.OnOffSwitchState(~obj.DisplayRowHidden);
            obj.AllPanelsMenu.Checked = matlab.lang.OnOffSwitchState( ...
                ~obj.DataColumnHidden && ~obj.DisplayRowHidden);
        end

        function tf = keyTargetIsTextEntry(obj)
            % True when the last thing clicked was somewhere text is typed.
            %
            % A uifigure hands every key press to WINDOWKEYPRESSFCN even while
            % an edit field has the caret, so the few shortcuts whose keys mean
            % something inside a field -- Ctrl+A, Ctrl+Z, Ctrl+Home, Ctrl+End --
            % have to know when to stand aside. CurrentObject is what a click
            % last landed on, which is how focus gets into a field in the first
            % place; it does not follow Tab, so it is used only to decline keys
            % the field wants, never to enable anything.

            tf = false;

            try
                target = obj.Fig.CurrentObject;
            catch
                return
            end

            if isempty(target) || ~isvalid(target)
                return
            end

            textEntry = ["matlab.ui.control.EditField", ...
                "matlab.ui.control.NumericEditField", ...
                "matlab.ui.control.TextArea", ...
                "matlab.ui.control.Spinner"];

            tf = ismember(string(class(target)), textEntry);

            if tf
                return
            end

            % A dropdown accepts typing only when it is editable, and the
            % catalog table is read only, so neither is listed outright.
            if isa(target, "matlab.ui.control.DropDown")
                tf = strcmp(string(target.Editable), "on");
            end
        end

        function syncBackgroundControls(obj)
            % Rebuild the background list around the color now in use, and fill
            % the dropdown with that color so it doubles as the swatch.

            if isempty(obj.BackgroundDropDown) || ~isvalid(obj.BackgroundDropDown)
                return
            end

            [names, codes, value] = obj.backgroundItems();

            % Items, ItemsData, and Value are set together because the list
            % length changes as a custom color comes and goes, and each of the
            % three on its own would disagree with the other two.
            set(obj.BackgroundDropDown, ...
                Items = names, ...
                ItemsData = num2cell(codes), ...
                Value = value);

            obj.BackgroundDropDown.BackgroundColor = obj.ImageBackground;
            obj.BackgroundDropDown.FontColor = obj.tileTextColor();

            % The menu carries the same list, and it is this function rather
            % than a value change that grows and shrinks the custom entry.
            obj.syncDisplayMenu();
        end

        function [names, codes, value] = backgroundItems(obj)
            % Build the background list: the presets, the custom color in use
            % when there is one, and the entry that opens the picker.
            %
            % The picker entry has to stay separate from the color it produced,
            % because a dropdown reports nothing when the value it already
            % holds is chosen again -- with one shared entry, a custom color
            % could never be adjusted a second time.

            names = HistologyImageBrowser.BackgroundNames;
            codes = HistologyImageBrowser.BackgroundCodes;

            value = HistologyImageBrowser.backgroundCode(obj.ImageBackground);

            if value == HistologyImageBrowser.CustomBackgroundCode
                names(end + 1) = sprintf("Custom  %.2f %.2f %.2f", obj.ImageBackground);
                codes(end + 1) = HistologyImageBrowser.CustomBackgroundCode;
            end

            names(end + 1) = "Choose color...";
            codes(end + 1) = HistologyImageBrowser.PickBackgroundCode;
        end

        function color = tileTextColor(obj)
            % Text color that stays legible on the current background.
            if HistologyImageBrowser.isDarkColor(obj.ImageBackground)
                color = [0.93 0.93 0.93];
            else
                color = [0.15 0.15 0.15];
            end
        end

        function color = tileAlertColor(obj)
            % Color for "could not read this" text on the current background.
            if HistologyImageBrowser.isDarkColor(obj.ImageBackground)
                color = [1.00 0.55 0.55];
            else
                color = [0.60 0.20 0.20];
            end
        end

        function stains = selectedStains(obj)
            % Distinct stains among the selected sections, ignoring blanks.
            stains = strings(0, 1);

            rows = obj.selectedRows();

            if isempty(rows) || height(rows) == 0
                return
            end

            stains = unique(strtrim(string(rows.Stain)));
            stains = stains(stains ~= "");
        end

        function name = stainColormap(obj, stain)
            % Colormap last chosen for one stain, or "" when it has none.
            name = "";

            index = find(obj.ColormapStains == string(stain), 1);

            if isempty(index)
                return
            end

            name = obj.ColormapChoices(index);
        end

        function rememberStainColormap(obj)
            % Tie the colormap now showing to the stain it is showing.
            % Only a single stain selection settles which stain a colormap
            % belongs to, so a mixed selection records nothing rather than
            % overwriting the choice made for every stain it holds.

            stains = obj.selectedStains();

            if numel(stains) ~= 1
                return
            end

            name = string(obj.ColormapDropDown.Value);
            index = find(obj.ColormapStains == stains, 1);

            if isempty(index)
                obj.ColormapStains(end + 1, 1) = stains;
                obj.ColormapChoices(end + 1, 1) = name;
                return
            end

            obj.ColormapChoices(index) = name;
        end

        function applyStainColormap(obj)
            % Show the colormap this stain was last displayed in.
            % A mixed selection is left alone for the same reason it records
            % nothing: no one stain owns what is on screen.

            stains = obj.selectedStains();

            if numel(stains) ~= 1
                return
            end

            name = obj.stainColormap(stains);

            if name == "" || ~ismember(name, string(obj.ColormapDropDown.Items))
                return
            end

            obj.ColormapDropDown.Value = name;

            % Set behind the dropdown's back, so nothing else will tell the
            % menu that the checked colormap moved.
            obj.syncDisplayMenu();
        end

        function onLayoutOptionChanged(obj)
            % Rearrange the view after the profile placement or size changes.
            obj.savePreferences();
            obj.applyViewLayout();

            % APPLYVIEWLAYOUT decides whether the profile size still applies,
            % so the menu is told after it has run rather than before.
            obj.syncDisplayMenu();

            % Tiles are not drawn while the image panel is hidden, so coming
            % back to a layout that shows them needs a full redraw.
            if obj.showImages()
                if isempty(obj.ImageLayout) || ~isvalid(obj.ImageLayout)
                    obj.renderSelection();
                    return
                end
            elseif ~isempty(obj.ImageLayout) && isvalid(obj.ImageLayout)
                % A layout that hides the tiles drops them rather than parking
                % them in a panel nobody can see. Each tile holds a decoded
                % page, so leaving them there made "Profiles only" go on
                % costing the memory of the view it had stopped showing until
                % the selection happened to move.
                delete(obj.ImageLayout);
            end

            obj.renderProfilePlot();
        end

        function code = profileLayout(obj)
            % Return the active layout code, falling back before the UI exists.
            code = "bottom";

            if ~isempty(obj.ProfileLayoutDropDown) && isvalid(obj.ProfileLayoutDropDown)
                code = string(obj.ProfileLayoutDropDown.Value);
            end
        end

        function tf = showProfile(obj)
            % True when the current layout gives the profile plot room.
            tf = obj.profileLayout() ~= "hidden";
        end

        function tf = showImages(obj)
            % True when the current layout gives the image tiles room.
            tf = obj.profileLayout() ~= "only";
        end

        function onSurfaceOverlayChanged(obj)
            % Redraw after the brain surface switch, which is the one overlay
            % option drawn in two places.
            %
            % Every other overlay is a graphic on a tile, so ONDISPLAY-
            % OPTIONCHANGED's cheap path -- REFRESHOVERLAYS, which replaces the
            % tagged objects on each tile and leaves the pictures standing --
            % is the whole redraw they need. The surface marks are also ruled
            % across the profile plot, and nothing REFRESHOVERLAYS does reaches
            % that, so the plot is redrawn here as well.
            %
            % Here rather than inside REFRESHOVERLAYS, because that runs for
            % every overlay switch and the other four have nothing to say about
            % the plot: redrawing it there would make a sampling band toggle
            % reread every selected section's profile to change nothing.

            obj.onDisplayOptionChanged();

            if ~obj.showProfile()
                return
            end

            % A change of settings large enough to have gone down
            % ONDISPLAYOPTIONCHANGED's expensive path has already redrawn the
            % plot, and this redraws it a second time. That costs one wasted
            % redraw in a case a click on this checkbox cannot produce, and the
            % alternative is a second copy of the render-key comparison here to
            % detect it.
            obj.renderProfilePlot();
        end

        function onProfileOptionChanged(obj)
            % Redraw the profile plot after a normalization choice.
            %
            % Only the profile plot. Normalization rescales the numbers on the
            % way to the axes and touches no pixel of a tile, so this does not
            % go through ONDISPLAYOPTIONCHANGED, whose work is to decide
            % whether the images have to be read and stretched again: there is
            % no setting here it could answer that question "yes" for.

            obj.savePreferences();
            obj.updateProfileControls();
            obj.syncDisplayMenu();

            if ~obj.showProfile()
                return
            end

            obj.renderProfilePlot();
        end

        function code = profileNorm(obj)
            % Active intensity normalization code.
            code = obj.profileOption(obj.ProfileNormDropDown, "none");
        end

        function code = profileScope(obj)
            % Active code for what a normalization is measured over.
            code = obj.profileOption(obj.ProfileScopeDropDown, "each");
        end

        function code = profileDistance(obj)
            % Active distance normalization code.
            code = obj.profileOption(obj.ProfileDistanceDropDown, "none");
        end

        function code = profileOption(~, control, fallback)
            % Read one profile dropdown's stored code, falling back to the
            % setting that changes nothing when the control is not there yet.
            % PROFILELAYOUT guards itself the same way and for the same
            % reason: the view is laid out while the window is still being
            % built, and a plot drawn then must not depend on the order the
            % panels happen to be created in.

            code = fallback;

            if ~isempty(control) && isvalid(control)
                code = string(control.Value);
            end
        end

        function tf = isEditingRow(obj, row)
            % True when this catalog row is the one being edited.
            tf = obj.RoiEditStem ~= "" && height(row) == 1 ...
                && string(row.Stem) == obj.RoiEditStem;
        end

        function tf = isEditedStemSelected(obj)
            % True when the section being edited is still selected.
            %
            % ISEDITINGROW answers for one row, which is the question a tile
            % asks. A selection holding several rows needs this weaker one, or
            % adding a second section to the selection would end an edit whose
            % own tile is still on screen.

            tf = false;

            if obj.RoiEditStem == ""
                return
            end

            rows = obj.selectedRows();

            if height(rows) == 0
                return
            end

            tf = any(string(rows.Stem) == obj.RoiEditStem);
        end

        function tf = isEditingRoi(obj, row, key)
            % True when this row's named ROI is the one being edited.
            % Only one ROI of one section is ever open at a time, so this is
            % what tells the overlay which line on a tile carries the handles
            % and which are simply drawn.
            tf = obj.isEditingRow(row) && string(key) == obj.RoiEditKey;
        end

        function keys = roiKeysForRow(obj, row)
            % Every ROI one section holds, in the order they are offered.
            %
            % An ROI being added is included before anything of it exists on
            % disk, because until it is saved the edit session is the only
            % place it lives, and it still has to be drawn and named.

            keys = strings(0, 1);

            if height(row) ~= 1
                return
            end

            if ismember("RoiKeys", string(row.Properties.VariableNames))
                keys = string(row.RoiKeys{1});
                keys = keys(:);
            end

            if obj.RoiEditKey ~= "" && obj.isEditingRow(row) ...
                    && ~ismember(obj.RoiEditKey, keys)
                keys(end + 1, 1) = obj.RoiEditKey;
            end
        end

        function E = roiEntry(obj, row, key)
            % The two sidecars of one ROI, either of which may be absent.
            %
            % Returns
            %   E: Struct with fields key, name, roiPath, and valuesPath. The
            %      paths are "" when that file has not been written yet.

            E = struct( ...
                "key", string(key), ...
                "name", obj.roiName(key), ...
                "roiPath", "", ...
                "valuesPath", "");

            if height(row) ~= 1
                return
            end

            varNames = string(row.Properties.VariableNames);

            if ~all(ismember(["RoiKeys", "RoiPaths", "RoiValues"], varNames))
                return
            end

            index = find(string(row.RoiKeys{1}) == E.key, 1);

            if isempty(index)
                return
            end

            roiPaths = string(row.RoiPaths{1});
            valuesPaths = string(row.RoiValues{1});

            if index <= numel(roiPaths)
                E.roiPath = roiPaths(index);
            end

            if index <= numel(valuesPaths)
                E.valuesPath = valuesPaths(index);
            end
        end

        function key = activeRoiKey(obj, row)
            % Which ROI of a section the edit controls act on right now.
            %
            % The key last chosen wins when the section has it, so moving
            % between sections stays on one region. Otherwise the section's
            % first ROI is taken, and a section with no ROI at all answers "A"
            % so that drawing on it has somewhere to put the result.

            keys = obj.roiKeysForRow(row);

            if obj.ActiveRoiKey ~= "" && ismember(obj.ActiveRoiKey, keys)
                key = obj.ActiveRoiKey;
                return
            end

            if isempty(keys)
                key = "A";
                return
            end

            key = keys(1);
        end

        function name = roiName(obj, key)
            % What one ROI key is called on screen, which is the key itself
            % until somebody names it.

            name = string(key);

            index = find(obj.RoiNameKeys == name, 1);

            if isempty(index) || obj.RoiNameLabels(index) == ""
                return
            end

            name = obj.RoiNameLabels(index);
        end

        function setRoiName(obj, key, name)
            % Name one ROI key, or clear the name by passing "".
            % Clearing removes the pair outright rather than storing a blank,
            % so the naming dialog and the saved preference hold only names
            % somebody actually chose.

            key = strtrim(string(key));
            name = strtrim(string(name));

            if key == ""
                return
            end

            index = find(obj.RoiNameKeys == key, 1);

            if name == "" || name == key
                if ~isempty(index)
                    obj.RoiNameKeys(index) = [];
                    obj.RoiNameLabels(index) = [];
                end

                return
            end

            if isempty(index)
                obj.RoiNameKeys(end + 1, 1) = key;
                obj.RoiNameLabels(end + 1, 1) = name;
                return
            end

            obj.RoiNameLabels(index) = name;
        end

        function text = describeRoiList(obj, row)
            % Name the ROIs one section holds, for the panel and the table.

            keys = obj.roiKeysForRow(row);

            if isempty(keys)
                text = "";
                return
            end

            names = arrayfun(@(k) obj.roiName(k), keys);
            text = join(names, ", ");
        end

        function text = roiListText(obj, rows)
            % DESCRIBEROILIST down a whole view, for the Sections table.
            %
            % CATALOGDISPLAYTABLE is static, so that APPLYFILTERS can build a
            % table for a view it has not adopted yet, and what an ROI key is
            % called is a setting of this browser rather than anything in the
            % catalog. This is where the two meet: the names are rendered here
            % and handed over already drawn.

            text = strings(height(rows), 1);

            for iRow = 1:height(rows)
                text(iRow) = obj.describeRoiList(rows(iRow, :));
            end
        end

        function pixelSize = roiEditPixelSize(obj)
            % Pixel size of the image the edited profile is measured from.
            % NaN when the image carries no calibration, in which case
            % distances are only ever reported in pixels.
            pixelSize = NaN;

            row = obj.editedRow();

            if height(row) ~= 1
                return
            end

            imagePath = obj.measureImagePath(row);

            if imagePath == ""
                return
            end

            % Reading the page sets this already; only an edit that has not
            % measured anything yet has to go back to the file header.
            if obj.MeasureKey == imagePath && isfinite(obj.MeasurePixelSize)
                pixelSize = obj.MeasurePixelSize;
                return
            end

            C = imagej_pixel_size(imagePath);

            if C.isCalibrated
                pixelSize = C.pixelSize;
            end
        end

        function text = describeRoiWidth(obj, width)
            % State a band width in pixels and, when the image is calibrated,
            % in microns as well. The macro's band is specified in microns and
            % this field is in pixels, so both are always shown together.
            text = sprintf("%g px", width);

            pixelSize = obj.roiEditPixelSize();

            if ~isfinite(pixelSize) || pixelSize <= 0
                return
            end

            % Spelled "um" rather than with the micron sign, which does not
            % survive every console and font this text is shown in.
            text = text + sprintf(" (%.0f um)", width * pixelSize);
        end

        function text = describeSurface(obj, R)
            % Say where the brain surface mark sits on a line, in the units
            % anyone reading the tile can check it in.
            %
            % Pixels because that is what the mark is stored in and what the
            % overlay is drawn in, microns beside them wherever the page is
            % calibrated, and a percentage of the line because that is the one
            % of the three that can be compared between two sections whose
            % lines are different lengths.
            %
            % Parameters
            %   R: Struct with x1, y1, x2, y2 and surface -- ROIFORROW's return
            %      or the ROI edit geometry, which carry the same fields.

            text = "not marked";

            if ~isfield(R, "surface") || ~isscalar(R.surface) || ~isfinite(R.surface)
                return
            end

            text = sprintf("at %.0f px", R.surface);

            pixelSize = obj.roiEditPixelSize();

            if isfinite(pixelSize) && pixelSize > 0
                % Spelled "um" rather than with the micron sign, which does not
                % survive every console and font this text is shown in.
                text = text + sprintf(" (%.0f um)", R.surface * pixelSize);
            end

            lineLength = hypot(double(R.x2) - double(R.x1), double(R.y2) - double(R.y1));

            if isfinite(lineLength) && lineLength > 0
                text = text + sprintf(", %.0f%% along the line", ...
                    100 * R.surface / lineLength);
            end
        end

        function row = editedRow(obj)
            % Return the row being edited, or an empty table when idle.
            row = obj.rowForStem(obj.RoiEditStem);
        end

        function row = rowForStem(obj, stem)
            % Row of the filtered view a section stem names, or an empty table.
            %
            % The view rather than the catalog, because a tile is only ever
            % drawn from a row that is in the view, and every other reader of
            % a row -- the overlay, the profile, the save -- looks there too.

            row = obj.View([], :);

            if stem == "" || height(obj.View) == 0
                return
            end

            index = find(string(obj.View.Stem) == stem, 1);

            if isempty(index)
                return
            end

            row = obj.View(index, :);
        end

        function ax = tileAxes(obj, stem)
            % Tile currently showing one section, or [] when it is not drawn.
            %
            % The stem DRAWIMAGETILE stamps on each axes is what picks the
            % right tile out of several: FINDOBJ returns them newest first, so
            % taking the first would land on the last section of the selection
            % rather than on the one being asked for.

            ax = [];

            if stem == "" || isempty(obj.ImagePanel) || ~isvalid(obj.ImagePanel)
                return
            end

            candidates = findobj(obj.ImagePanel, Type = "axes");

            for iAxes = 1:numel(candidates)
                if HistologyImageBrowser.tileStem(candidates(iAxes)) == stem
                    ax = candidates(iAxes);
                    return
                end
            end
        end

        function stem = activeRoiStem(obj)
            % Section the ROI controls act on, or "" when none is selected.
            %
            % An edit already open owns the line whichever tile it sits on.
            % Otherwise the tile the user last clicked takes it, and failing
            % that the first drawn tile does. ONTOGGLEEDITROI, ONDRAWROI and
            % ONOPENFOLDER all ask here rather than each reaching for the first
            % selected row, which is what lets the tile say which section is
            % next before a button is pressed instead of the user finding out
            % by pressing one.
            %
            % The answer is always a section that is drawn, never merely one
            % that is selected: a stem beyond the Max tiles cap, or one left
            % over from a selection that has moved on, is ignored rather than
            % named. That makes ROITARGETSTEM self-healing, so nothing has to
            % remember to clear it.

            stem = obj.RoiEditStem;

            if stem ~= ""
                return
            end

            stems = obj.drawnStems();

            if isempty(stems)
                return
            end

            if obj.RoiTargetStem ~= "" && any(stems == obj.RoiTargetStem)
                stem = obj.RoiTargetStem;
                return
            end

            stem = stems(1);
        end

        function stems = drawnStems(obj)
            % Sections RENDERSELECTION would draw a tile for, in tile order.
            %
            % The selection truncated to the Max tiles cap, which is the same
            % arithmetic RENDERSELECTION and ONOPENINFIGURE do. Read off the
            % table rather than off the tiles themselves, so it answers the
            % same way in a layout that draws no tiles at all -- the ROI hint
            % has to name a section there too.

            stems = strings(0, 1);

            rows = obj.selectedRows();

            if isempty(rows) || height(rows) == 0
                return
            end

            nDrawn = min(height(rows), obj.maxTiles());

            stems = string(rows.Stem(1:nDrawn));
        end

        function n = maxTiles(obj)
            % Most tiles the view will draw at once, as a whole number.
            % One while the field is still being built, so a caller running
            % before the panel exists sees the cap it always had a floor of.

            n = 1;

            if isempty(obj.MaxTilesField) || ~isvalid(obj.MaxTilesField)
                return
            end

            n = max(1, round(obj.MaxTilesField.Value));
        end

        function onOpenFolder(obj)
            % Reveal the folder holding the image of the marked section.
            %
            % Through ACTIVEROISTEM rather than off the first selected row, so
            % a right-click on the sixth tile opens the sixth section's folder.
            % With nothing clicked the two are the same section anyway.

            row = obj.rowForStem(obj.activeRoiStem());

            if height(row) ~= 1
                obj.setWarning("Select an image first.");
                uialert(obj.Fig, "Select an image first.", "Nothing Selected");
                return
            end

            folder = row.Folder(1);

            if folder == "" || ~isfolder(folder)
                obj.setError("Folder is missing for this entry: %s", folder);
                uialert(obj.Fig, "No folder is available for this entry.", "Folder Missing");
                return
            end

            if ispc
                winopen(folder);
            elseif ismac
                system("open """ + folder + """ &");
            else
                system("xdg-open """ + folder + """ &");
            end
        end

        function onOpenAtlasExplorer(obj)
            % Open the gerbil atlas explorer in the default browser.
            obj.openExternalLink(HistologyImageBrowser.AtlasExplorerURL, ...
                "the gerbil atlas explorer");
        end

        function opened = openExternalLink(obj, url, description)
            % Hand a URL to the default browser, reporting a refusal rather
            % than throwing.
            %
            % The system browser is asked for by name: the atlas explorer needs
            % a current engine, and nobody is signed in to GitHub inside
            % MATLAB's own browser. A release that will not honor "-browser"
            % falls back to whatever it will open rather than opening nothing.

            opened = true;

            try
                web(url, "-browser");
                return
            catch ME
                reason = ME.message;
            end

            try
                web(url);
            catch
                opened = false;
                obj.setError("Could not open %s: %s", description, reason);
                uialert(obj.Fig, ...
                    "Could not open a browser for:" + newline + url, ...
                    "Browser Failed");
            end
        end

        function setStatus(obj, varargin)
            % Report ordinary progress on the status bar.
            obj.pushStatus("info", varargin{:});
        end

        function setBusy(obj, varargin)
            % Report work that is under way and has not finished yet.
            obj.pushStatus("busy", varargin{:});
        end

        function setSuccess(obj, varargin)
            % Report work that finished cleanly.
            obj.pushStatus("success", varargin{:});
        end

        function setWarning(obj, varargin)
            % Report something the user should notice but that did not stop the work.
            obj.pushStatus("warning", varargin{:});
        end

        function setError(obj, varargin)
            % Report work that failed.
            obj.pushStatus("error", varargin{:});
        end

        function pushStatus(obj, level, varargin)
            % Write one message to the status bar and flush it to the screen.
            % Dialogs come and go, so the bar keeps the last few messages in its
            % tooltip and holds the most recent one until something replaces it.

            if isempty(obj.StatusLabel) || ~isvalid(obj.StatusLabel)
                return
            end

            % A lone argument is taken verbatim, so a message holding a file
            % path with a backslash or a percent sign survives intact.
            if numel(varargin) == 1
                message = string(varargin{1});
            else
                message = string(sprintf(varargin{:}));
            end

            style = HistologyImageBrowser.statusStyle(level);
            obj.StatusLevel = style.level;

            obj.StatusLabel.Text = message;
            obj.StatusLabel.FontColor = style.text;
            obj.StatusLabel.FontWeight = style.weight;

            if ~isempty(obj.StatusLamp) && isvalid(obj.StatusLamp)
                obj.StatusLamp.Text = style.glyph;
                obj.StatusLamp.FontColor = style.lamp;
            end

            if ~isempty(obj.StatusBar) && isvalid(obj.StatusBar)
                obj.StatusBar.BackgroundColor = style.background;
            end

            stamp = string(datetime("now", Format = "HH:mm:ss"));

            if ~isempty(obj.StatusDetail) && isvalid(obj.StatusDetail)
                obj.StatusDetail.Text = stamp;
            end

            obj.StatusHistory(end + 1, 1) = stamp + "  " + upper(style.level) + "  " + message;

            if numel(obj.StatusHistory) > obj.MaxStatusHistory
                obj.StatusHistory = obj.StatusHistory(end - obj.MaxStatusHistory + 1:end);
            end

            % Newest first, so the tooltip opens on what just happened.
            obj.StatusLabel.Tooltip = join(flipud(obj.StatusHistory), newline);

            % A busy message is usually followed immediately by more work, so it
            % may be coalesced; anything the user has to act on is flushed.
            if style.level == "busy" || style.level == "info"
                drawnow limitrate
            else
                drawnow
            end
        end
    end

    methods (Static)
        summary = missingMetadata(row)  % Name the annotations a section lacks.

        bindings = keyBindings()        % Every keyboard shortcut, in one table.

        style = roiStateStyle(state, tileColor)  % Aesthetics for one ROI save state.

        function point = surfacePoint(R)
            % Image coordinates of the brain surface mark on a line ROI, or []
            % when the line carries no mark.
            %
            % The mark is stored as a distance from the line's start rather
            % than as a point, because that is what survives the far end of the
            % line being dragged. Everything that draws it -- the tick on the
            % tile, the draggable handle, the exported columns -- turns it back
            % into a point here rather than each doing the arithmetic itself.
            %
            % Parameters
            %   R: Struct with x1, y1, x2, y2 and surface, as ROIFORROW and the
            %      ROI edit geometry both carry.

            point = [];

            if ~isfield(R, "surface") || ~isscalar(R.surface) || ~isfinite(R.surface)
                return
            end

            delta = [double(R.x2) - double(R.x1), double(R.y2) - double(R.y1)];
            lineLength = hypot(delta(1), delta(2));

            if ~isfinite(lineLength) || lineLength <= 0
                return
            end

            % Clamped rather than refused, so a mark left over from a longer
            % line lands on the end of the shorter one instead of floating off
            % past it. The stroke says the line is unsaved either way.
            offset = min(max(double(R.surface), 0), lineLength);

            point = [double(R.x1), double(R.y1)] + offset * delta / lineLength;
        end

        function offset = projectOntoLine(R, point)
            % Distance from a line's start to the foot of a point's
            % perpendicular, clamped to the line. This is what turns a click or
            % a drag anywhere near the line into a surface offset, so the mark
            % can never end up somewhere the profile was not measured.
            %
            % Returns NaN for a line with no length, which has no offsets.

            offset = NaN;

            delta = [double(R.x2) - double(R.x1), double(R.y2) - double(R.y1)];
            lineLength = hypot(delta(1), delta(2));

            if ~isfinite(lineLength) || lineLength <= 0
                return
            end

            unit = delta / lineLength;
            fromStart = [double(point(1)) - double(R.x1), double(point(2)) - double(R.y1)];

            offset = min(max(dot(fromStart, unit), 0), lineLength);
        end

        [tf, message] = checkFilenamePattern(pattern)  % Judge a candidate pattern.

        pattern = tokenListPattern(delimiter, names)   % Compile a token list into one.

        T = filenamePatternPreview(names, pattern)     % What a pattern extracts, tabulated.

        [display, widths] = catalogDisplayTable(rows, columns, options)  % Table the Sections widget shows.

        idx = catalogSortOrder(display, heading, direction)     % Order one column sort gives.

        N = normalizeProfiles(profiles, options)  % Rescale profiles for plotting.

        function stem = tileStem(ax)
            % Section a tile was drawn for, or "" for an axes that is not one.
            % DRAWIMAGETILE stamps it, so anything holding an axes can ask
            % which section it belongs to without knowing the tile order.

            stem = "";

            if isempty(ax) || ~isvalid(ax) || ~isstruct(ax.UserData) ...
                    || ~isfield(ax.UserData, "Stem")
                return
            end

            stem = string(ax.UserData.Stem);
        end

        function colors = tileColors(n)
            % One distinguishable color per tile, all legible on a dark image.
            %
            % A tile's color is the only thing tying a picture to its trace in
            % the profile plot, so the three places that draw them --
            % RENDERSELECTION, RENDERPROFILEPLOT and ONOPENINFIGURE -- all come
            % here instead of each calling LINES or TURBO for itself.
            %
            % Both of those maps run dark at their ends: LINES opens on a navy
            % and TURBO on a near-black violet. That color is not only the
            % frame; it strokes the ROI across the section and now titles the
            % tile from inside it, and sections are usually near-black
            % fluorescence, so a navy line on one is not a line anyone can see.
            % Hue is what identifies a tile, so hue is the one thing left
            % alone: every color is lifted to at least MINVALUE and has its
            % saturation capped, which keeps the set as separable as it was
            % while none of it can sink into the background.

            arguments
                n (1,1) double
            end

            n = max(round(n), 1);

            if n <= 7
                colors = lines(n);
            else
                colors = turbo(n);
            end

            minValue = 0.78;
            maxSaturation = 0.85;

            hsv = rgb2hsv(colors);
            hsv(:, 2) = min(hsv(:, 2), maxSaturation);
            hsv(:, 3) = max(hsv(:, 3), minValue);

            colors = hsv2rgb(hsv);
        end

        function color = tileColor(ax, fallback)
            % Color a tile's frame and overlay were drawn in.
            % An axes drawn before the stamp existed, or one that is not a
            % tile, falls back to the first tile color rather than to nothing,
            % because every caller is about to draw with it.

            arguments
                ax
                fallback (1,3) double = HistologyImageBrowser.tileColors(1)
            end

            color = fallback;

            if isempty(ax) || ~isvalid(ax) || ~isstruct(ax.UserData) ...
                    || ~isfield(ax.UserData, "TileColor")
                return
            end

            candidate = ax.UserData.TileColor;

            if isnumeric(candidate) && numel(candidate) == 3
                color = double(candidate(:))';
            end
        end

        function markTile(ax, isActive)
            % Say on one tile whether it is the section the ROI controls act
            % on, without redrawing anything else about it.
            %
            % The whole mark is here rather than split between DRAWIMAGETILE
            % and MARKROITARGET, because the two have to agree exactly: a tile
            % drawn active and a tile marked active later must be the same
            % picture, or moving the target would leave two tiles looking
            % subtly different from each other and from the panel.
            %
            % Two channels carry it. The frame weight is the one thing
            % readable from across a grid of twelve sections and the one that
            % survives the figure being printed in grey; the label states it in
            % words for anyone who cannot tell two stroke widths apart. The
            % active label inverts its plate -- the tile's own color filled in,
            % with dark text on it -- which reads at a glance and does not
            % depend on remembering which of two colors means what.
            %
            % Parameters
            %   isActive: True for the tile the ROI controls act on.
            %
            % See also DRAWIMAGETILE, MARKROITARGET, ACTIVEROISTEM.

            arguments
                ax
                isActive (1,1) logical
            end

            if isempty(ax) || ~isvalid(ax)
                return
            end

            if isActive
                ax.LineWidth = 3;
            else
                ax.LineWidth = 1.5;
            end

            label = findobj(ax, Tag = "tileTitle");

            if numel(label) ~= 1
                return
            end

            % PLACE_TITLE keeps the unmarked wording here, because the marked
            % wording cannot be turned back into it by trimming a suffix
            % without this code and that code sharing a literal.
            base = string(label.UserData);

            if ~isscalar(base) || ismissing(base) || strlength(base) == 0
                % A label from somewhere that did not record its plain wording.
                % Rewriting it would risk stacking one suffix on another, so the
                % frame weight set above carries the mark by itself.
                return
            end

            if isActive
                label.String = base + "  (ROI target)";
                label.BackgroundColor = HistologyImageBrowser.tileColor(ax);
                label.Color = [0.06 0.06 0.06];
                label.FontWeight = "bold";
                return
            end

            label.String = base;
            label.BackgroundColor = [0.09 0.09 0.09];
            label.Color = HistologyImageBrowser.tileColor(ax);
            label.FontWeight = "normal";
        end

        function root = repositoryRoot()
            % Folder the app was loaded from, which is the git checkout when
            % there is one. Methods live one level down, in the class folder,
            % so the root is two steps up from this file.

            root = string(fileparts(fileparts(mfilename("fullpath"))));
        end

        function key = nextRoiKey(usedKeys)
            % Name the next ROI a section gains: the first letter it is not
            % already using. Letters rather than numbers, because the label
            % goes into a filename beside the section's own name, where "_B_"
            % cannot be mistaken for part of the section, slide, or z index
            % that surround it.

            usedKeys = string(usedKeys(:));
            letters = string(char((double('A'):double('Z'))'));

            free = letters(~ismember(letters, usedKeys));

            if isempty(free)
                % Twenty-six lines across one section is far past what the
                % study measures, so this only has to be unique, not pretty.
                key = "R" + string(numel(usedKeys) + 1);
                return
            end

            key = free(1);
        end

        function label = shortcutLabel(binding)
            % Render one binding the way a menu names a shortcut, e.g.
            % "Ctrl+Shift+R". Modifiers are always written in the same order,
            % whatever order the key event happened to report them in.

            names = ["control", "alt", "shift"];
            shown = ["Ctrl", "Alt", "Shift"];

            parts = shown(ismember(names, binding.Modifier));
            parts(end + 1) = HistologyImageBrowser.keyLabel(binding.Key);

            label = strjoin(parts, "+");
        end

        function hint = shortcutHint(action)
            % Name the key that runs an action, parenthesized for a menu item
            % or the tail of a tooltip. It is read out of the binding table so
            % a control cannot advertise a shortcut that was renamed or
            % dropped, and it comes back empty when the action has no key.

            bindings = HistologyImageBrowser.keyBindings();
            match = bindings(string({bindings.Action}) == string(action));

            if isempty(match)
                hint = "";
                return
            end

            hint = "  (" + HistologyImageBrowser.shortcutLabel(match(1)) + ")";
        end

        function label = keyLabel(key)
            % Name one key the way a keyboard does rather than the way a key
            % press event does.

            known = ["uparrow", "downarrow", "leftarrow", "rightarrow", "escape"];
            shown = ["Up", "Down", "Left", "Right", "Esc"];

            index = find(known == string(key), 1);

            if ~isempty(index)
                label = shown(index);
                return
            end

            % Function keys and single characters both read best in capitals,
            % and every other key name is already a word.
            label = upper(string(key));

            if strlength(label) > 2 && ~startsWith(label, "F")
                label = extractBefore(label, 2) + lower(extractAfter(label, 1));
            end
        end

        function label = menuPathLabel(path, emptyText)
            % Shorten a path enough to sit on a menu item without pushing the
            % menu across the screen. The full root path stays in the window
            % title, so only the tail has to be recognizable here.

            path = strtrim(string(path));

            if path == ""
                label = "(" + string(emptyText) + ")";
                return
            end

            parts = split(path, ["\", "/"]);
            parts(parts == "") = [];

            if numel(parts) > 2
                label = "..." + filesep + join(parts(end-1:end), filesep);
            else
                label = path;
            end
        end

        function marks = measuredMarks(measured)
            % Render the measured flag as a column that stays narrow: a tick
            % for a section that has been measured and a blank for one that has
            % not. Shared by CATALOGDISPLAYTABLE, which draws the column on a
            % full refresh, and REFRESHREVIEWCOLUMNS, which rewrites it in
            % place after a review is written to the tracker, so the two cannot
            % render the same flag differently.

            measured = logical(measured(:));

            marks = strings(numel(measured), 1);
            marks(measured) = char(10003);
        end

        function label = publishedSheetLabel(url)
            % Name the published sheet on the menu without the key. A published
            % URL is a hundred characters of document key and query string,
            % none of it readable, and a menu item that wide would push the
            % menu off the screen. The gid is the one part that distinguishes
            % one published tab from another, so that is what is shown; the
            % whole URL is in the dialog that sets it.

            url = strtrim(string(url));

            if url == ""
                label = "(none)";
                return
            end

            gid = regexp(url, "gid=(\d+)", "tokens", "once");

            if isempty(gid)
                label = "set";
                return
            end

            label = "set (gid " + string(gid{1}) + ")";
        end

        function color = backgroundColor(code)
            % Resolve a background preset code to its RGB triplet.
            % "custom" has no fixed color, so it falls back to the default
            % rather than returning something the caller has to check for.

            index = find(HistologyImageBrowser.BackgroundCodes == string(code), 1);

            if isempty(index) || index > size(HistologyImageBrowser.BackgroundColors, 1)
                color = HistologyImageBrowser.BackgroundColors(2, :);
                return
            end

            color = HistologyImageBrowser.BackgroundColors(index, :);
        end

        function code = backgroundCode(color)
            % Name the preset a color matches, or "custom" when it matches none.

            code = "custom";

            if ~isnumeric(color) || numel(color) ~= 3
                return
            end

            presets = HistologyImageBrowser.BackgroundColors;
            distance = max(abs(presets - double(color(:)')), [], 2);
            index = find(distance < 0.01, 1);

            if isempty(index)
                return
            end

            code = HistologyImageBrowser.BackgroundCodes(index);
        end

        function tf = isDarkColor(color)
            % True when text on this color has to be light to stay readable.
            % Weighted for perceived brightness rather than a plain mean, so a
            % saturated green does not read as darker than it looks.

            tf = false;

            if ~isnumeric(color) || numel(color) ~= 3
                return
            end

            color = double(color(:)');
            tf = (0.2126 * color(1) + 0.7152 * color(2) + 0.0722 * color(3)) < 0.45;
        end

        function style = statusStyle(level)
            % Resolve the lamp glyph, colors, and weight for one severity.

            level = string(level);
            index = find(HistologyImageBrowser.StatusLevels == level, 1);

            if isempty(index)
                level = "info";
                index = 1;
            end

            style = struct( ...
                level = level, ...
                glyph = HistologyImageBrowser.StatusGlyphs(index), ...
                weight = "normal", ...
                lamp = [0.45 0.45 0.45], ...
                text = [0.15 0.15 0.15], ...
                background = [0.94 0.94 0.94]);

            switch level
                case "busy"
                    style.lamp = [0.00 0.45 0.74];
                    style.background = [0.90 0.94 0.98];

                case "success"
                    style.lamp = [0.16 0.55 0.24];
                    style.background = [0.90 0.96 0.90];

                case "warning"
                    style.lamp = [0.85 0.55 0.05];
                    style.text = [0.45 0.30 0.00];
                    style.background = [1.00 0.96 0.85];

                case "error"
                    style.lamp = [0.75 0.10 0.10];
                    style.text = [0.60 0.05 0.05];
                    style.weight = "bold";
                    style.background = [1.00 0.90 0.90];
            end
        end
    end
end
