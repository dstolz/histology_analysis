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
        ViewColumnGrid matlab.ui.container.GridLayout
        ViewGrid matlab.ui.container.GridLayout

        DatasetMenu matlab.ui.container.Menu
        RootFolderMenu matlab.ui.container.Menu
        MetadataMenu matlab.ui.container.Menu
        ClearMetadataMenu matlab.ui.container.Menu
        LoadMenu matlab.ui.container.Menu

        DisplayMenu matlab.ui.container.Menu

        % One entry per Display menu item that mirrors a panel control, so
        % SYNCDISPLAYMENU can walk the menu without a handle property each.
        DisplayMirrors struct = struct([])

        ViewMenu matlab.ui.container.Menu
        DataColumnMenu matlab.ui.container.Menu
        DisplayRowMenu matlab.ui.container.Menu
        AllPanelsMenu matlab.ui.container.Menu
        ShortcutsMenu matlab.ui.container.Menu

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

        BackgroundDropDown matlab.ui.control.DropDown

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

        StatusLevel string = "info" % Severity of the message now on the status bar.
        StatusHistory string = strings(0, 1)

        RoiEditStem string = ""     % Stem being edited; empty when idle.
        RoiEditGeom struct = struct()   % Unsaved x1, y1, x2, y2, strokeWidth, name.
        RoiEditDirty logical = false    % True when the edit differs from the file.
        RoiPreview struct = struct()    % Profile measured from the unsaved geometry.
        RoiEditor = []              % images.roi.Line drawn on the edited tile.

        % True between the first move of a drag and the mouse coming back up.
        % The shading under the band is measured data, and data measured from a
        % line that is still moving would be wrong, so it is left out until the
        % drag ends.
        RoiEditDragging logical = false

        % Stem whose ROI was written to disk in this session. It drives the
        % green "saved" aesthetic on the tile, which outlives the edit session
        % so leaving edit mode does not erase the confirmation, and is cleared
        % as soon as the selection moves on or the line is touched again.
        RoiSavedStem string = ""

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

        % Status severities, and the lamp glyph each one shows.
        StatusLevels = ["info", "busy", "success", "warning", "error"]
        StatusGlyphs = string(char([9679; 9680; 9679; 9650; 9632]))

        % Placement choices for the profile plot, and their stored codes.
        ProfileLayoutNames = ["Below images", "Above images", "Left of images", "Right of images", "Hidden", "Profiles only"]
        ProfileLayoutCodes = ["bottom", "top", "left", "right", "hidden", "only"]

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

        applyRoiEditorStyle(obj)        % Recolor the draggable line for the current state.

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

        onFigureKeyPress(obj, evt)      % Match a key press to a shortcut.

        runShortcut(obj, action)        % Carry out one named shortcut.

        onShowShortcuts(obj)            % List every shortcut in a dialog.

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
            obj.syncDisplayMenu();
            obj.renderSelection();
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

        bindings = keyBindings()        % Every keyboard shortcut, in one table.

        style = roiStateStyle(state, tileColor)  % Aesthetics for one ROI save state.

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
