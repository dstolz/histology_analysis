classdef HistologyImageBrowser < handle
    %HISTOLOGYIMAGEBROWSER Browse histology images and overlay line-profile data.
    %
    %   app = HistologyImageBrowser()
    %   app = HistologyImageBrowser(rootPath)
    %   app = HistologyImageBrowser(rootPath, metadataCSV = trackerPath)
    %
    % Loads a histology root folder with COMBINE_VALUES_CSV, catalogs every
    % image rendition found beside the values files, and provides filtered
    % lookup plus single or multi-image display. The line ROI written by the
    % Fiji line-measure macro can be overlaid on each image, optionally shaded
    % by the intensities recorded in the matching *values.csv file.
    %
    % See also COMBINE_VALUES_CSV, BUILD_HISTOLOGY_IMAGE_CATALOG,
    % READ_IMAGEJ_ROI, LAUNCH_HISTOLOGY_BROWSER.

    properties
        Fig matlab.ui.Figure
        MainGrid matlab.ui.container.GridLayout
        ContentGrid matlab.ui.container.GridLayout
        BrowseGrid matlab.ui.container.GridLayout
        ViewGrid matlab.ui.container.GridLayout

        DatasetMenu matlab.ui.container.Menu
        RootFolderMenu matlab.ui.container.Menu
        MetadataMenu matlab.ui.container.Menu
        ClearMetadataMenu matlab.ui.container.Menu
        LoadMenu matlab.ui.container.Menu

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

        VariantDropDown matlab.ui.control.DropDown
        ChannelDropDown matlab.ui.control.DropDown
        ColormapDropDown matlab.ui.control.DropDown
        LowPercentileField matlab.ui.control.NumericEditField
        HighPercentileField matlab.ui.control.NumericEditField
        MaxTilesField matlab.ui.control.NumericEditField

        ShowRoiCheck matlab.ui.control.CheckBox
        ShowBandCheck matlab.ui.control.CheckBox
        ColorByIntensityCheck matlab.ui.control.CheckBox
        ProfileLayoutDropDown matlab.ui.control.DropDown
        ProfileSizeField matlab.ui.control.NumericEditField

        EditRoiButton matlab.ui.control.StateButton
        RoiWidthField matlab.ui.control.NumericEditField
        DrawRoiButton matlab.ui.control.Button
        SaveRoiButton matlab.ui.control.Button
        RevertRoiButton matlab.ui.control.Button
        RoiEditLabel matlab.ui.control.Label

        NewFigureButton matlab.ui.control.Button
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
    end

    properties
        RootPath string = ""        % Folder scanned for images and values files.
        MetadataPath string = ""    % Optional section tracker CSV.

        Data struct = struct()      % Structured output from COMBINE_VALUES_CSV.
        Catalog table = table()     % One row per image stem.
        View table = table()        % Catalog rows passing the active filters.
        Selection double = []       % Row indices into View.
        ImageCache = []             % containers.Map of decoded display images.
        CacheOrder string = strings(0, 1)

        % Colormap last chosen for each stain, kept as parallel lists.
        % Selecting a section brings back the colormap its stain was last
        % shown in, so moving between stains does not mean setting it again.
        ColormapStains string = strings(0, 1)
        ColormapChoices string = strings(0, 1)

        StatusLevel string = "info" % Severity of the message now on the status bar.
        StatusHistory string = strings(0, 1)

        RoiEditStem string = ""     % Stem being edited; empty when idle.
        RoiEditGeom struct = struct()   % Unsaved x1, y1, x2, y2, strokeWidth, name.
        RoiEditDirty logical = false    % True when the edit differs from the file.
        RoiPreview struct = struct()    % Profile measured from the unsaved geometry.
        RoiEditor = []              % images.roi.Line drawn on the edited tile.

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

        % Status severities, and the lamp glyph each one shows.
        StatusLevels = ["info", "busy", "success", "warning", "error"]
        StatusGlyphs = string(char([9679; 9680; 9679; 9650; 9632]))

        % Placement choices for the profile plot, and their stored codes.
        ProfileLayoutNames = ["Below images", "Above images", "Left of images", "Right of images", "Hidden", "Profiles only"]
        ProfileLayoutCodes = ["bottom", "top", "left", "right", "hidden", "only"]
    end

    methods
        function obj = HistologyImageBrowser(rootPath, options)
            % Construct the browser, optionally loading a dataset immediately.

            arguments
                rootPath (1,1) string = ""
                options.metadataCSV (1,1) string = ""
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

            obj.refreshDatasetMenu();

            if rootPath ~= ""
                obj.onLoadData();
            end
        end

        buildUI(obj)                    % Build the figure and all panels.

        buildDatasetMenu(obj)           % Build the Dataset menu on the menu bar.

        buildFilterPanel(obj, parent)   % Build the lookup and filter controls.

        buildCatalogTable(obj, parent)  % Build the results table and navigation.

        buildDisplayPanel(obj, parent)  % Build the display and overlay controls.

        buildViewPanel(obj, parent)     % Build the image tiles and profile axes.

        buildStatusBar(obj, parent)     % Build the status strip along the bottom.

        applyViewLayout(obj)            % Place the image and profile panels per the layout choice.

        onLoadData(obj)                 % Run COMBINE_VALUES_CSV and build the catalog.

        refreshFilterChoices(obj)       % Repopulate filter lists from the catalog.

        applyFilters(obj)               % Filter the catalog and refresh the table.

        refreshCatalogTable(obj)        % Push the filtered view into the table.

        onSelectionChanged(obj)         % Handle a table selection change.

        renderSelection(obj)            % Draw the selected images and profiles.

        drawImageTile(obj, ax, row, tileColor)  % Draw one image with its overlay.

        drawRoiOverlay(obj, ax, row, tileColor) % Draw the line ROI and sampling band.

        renderProfilePlot(obj)          % Draw profiles for the current selection.

        [img, imageSize, reason] = loadDisplayImage(obj, imagePath, page)  % Load and cache one image.

        P = readProfile(obj, row)       % Read profile data for one catalog row.

        R = roiForRow(obj, row)         % Line ROI to draw for a row, edited or on disk.

        geometry = initialRoiGeometry(obj, row)  % Geometry an edit session starts from.

        onToggleEditRoi(obj)            % Enter or leave ROI editing.

        proceed = exitRoiEdit(obj, askWhenDirty) % Leave editing, offering to save first.

        attachRoiEditor(obj, ax, row)   % Put the draggable line on the edited tile.

        onRoiEditChanged(obj, position, isFinal) % Take a new position from the drag.

        onRoiWidthChanged(obj)          % Apply a new sampling band width.

        onDrawRoi(obj)                  % Draw a new line ROI on the image.

        imagePath = measureImagePath(obj, row)  % Image a profile is measured from.

        refreshRoiOverlay(obj)          % Redraw just the edited tile's overlay.

        updateRoiPreview(obj)           % Remeasure the profile under the unsaved ROI.

        M = loadMeasureImage(obj, row)  % Load the page profiles are measured from.

        onSaveRoiEdits(obj)             % Write the ROI and its profile back to disk.

        onRevertRoiEdits(obj)           % Go back to the ROI on disk.

        updateRoiEditControls(obj)      % Enable the ROI controls that apply now.

        imagePath = resolveImagePath(obj, row)  % Resolve the selected rendition path.

        rows = selectedRows(obj)        % Return the catalog rows currently selected.

        onExportView(obj)               % Export the current view to an image file.

        onOpenInFigure(obj)             % Redraw the current selection in a normal figure.

        loadPreferences(obj)            % Restore saved paths and display settings.

        savePreferences(obj)            % Persist paths and display settings.

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

            if obj.RootPath == ""
                obj.Fig.Name = "Histology Image Browser";
            else
                obj.Fig.Name = "Histology Image Browser  -  " + obj.RootPath;
            end
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
            % Redraw after a display or overlay option changes.
            obj.savePreferences();
            obj.renderSelection();
        end

        function onColormapChanged(obj)
            % Take a new colormap and tie it to the stain now on screen.
            obj.rememberStainColormap();
            obj.onDisplayOptionChanged();
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
        end

        function onLayoutOptionChanged(obj)
            % Rearrange the view after the profile placement or size changes.
            obj.savePreferences();
            obj.applyViewLayout();

            % Tiles are not drawn while the image panel is hidden, so coming
            % back to a layout that shows them needs a full redraw.
            if obj.showImages() && (isempty(obj.ImageLayout) || ~isvalid(obj.ImageLayout))
                obj.renderSelection();
                return
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

        function tf = isEditingRow(obj, row)
            % True when this catalog row is the one being edited.
            tf = obj.RoiEditStem ~= "" && height(row) == 1 ...
                && string(row.Stem) == obj.RoiEditStem;
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

        function row = editedRow(obj)
            % Return the row being edited, or an empty table when idle.
            row = obj.View([], :);

            if obj.RoiEditStem == "" || height(obj.View) == 0
                return
            end

            index = find(string(obj.View.Stem) == obj.RoiEditStem, 1);

            if isempty(index)
                return
            end

            row = obj.View(index, :);
        end

        function onOpenFolder(obj)
            % Reveal the folder holding the first selected image.
            rows = obj.selectedRows();

            if isempty(rows) || height(rows) == 0
                obj.setWarning("Select an image first.");
                uialert(obj.Fig, "Select an image first.", "Nothing Selected");
                return
            end

            folder = rows.Folder(1);

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
