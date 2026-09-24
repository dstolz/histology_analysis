function onOpenInFiji(obj)
%ONOPENINFIJI Open the marked section's image in Fiji, with its line ROIs.
% The image is the rendition on screen, resolved the way the tile resolved it,
% so what opens in Fiji is the picture that was being looked at. Each of the
% section's saved .roi files is laid over it as an overlay named for its key,
% and the ROI the edit controls point at is left as the live selection, so it
% can be measured or moved in Fiji straight away.
%
% The ROIs go onto the image's overlay rather than into the ROI Manager. The
% ROI Manager belongs to the whole Fiji session, and a Fiji already open on
% other work would have its list emptied or added to by every section sent
% here; an overlay belongs to the one image it arrived with.
%
% Only what is on disk is sent. An ROI being edited here and not yet saved is
% invisible to Fiji, and the status bar says so rather than letting the older
% line on disk pass for the one on screen.
%
% Fiji is started through a short macro written to the temp folder, because a
% macro is the one thing every Fiji launcher, old and new, accepts on its
% command line. With Fiji's single-instance listener switched on (Edit >
% Options > Misc) the macro runs in the Fiji already open; otherwise a new
% Fiji starts.
%
% See also ONOPENFOLDER, ONOPENINFIGURE, RESOLVEIMAGEPATH, ROIENTRY.

row = obj.rowForStem(obj.activeRoiStem());

if height(row) ~= 1
    obj.setWarning("Select an image first.");
    uialert(obj.Fig, "Select an image first.", "Nothing Selected");
    return
end

imagePath = obj.resolveImagePath(row);

if imagePath == ""
    obj.setError("No image file is available for %s.", row.Stem(1));
    uialert(obj.Fig, "No image file is available for this section.", "Image Missing");
    return
end

fijiPath = locate_fiji(obj);

if fijiPath == ""
    obj.setWarning("Fiji was not opened: no Fiji launcher was chosen.");
    return
end

% The active key goes last so its ROI is the one left selected.
activeKey = obj.activeRoiKey(row);
keys = obj.roiKeysForRow(row);
keys = [keys(keys ~= activeKey); keys(keys == activeKey)];

roiPaths = strings(0, 1);
roiNames = strings(0, 1);

for iKey = 1:numel(keys)
    entry = obj.roiEntry(row, keys(iKey));

    if entry.roiPath ~= "" && isfile(entry.roiPath)
        roiPaths(end + 1, 1) = entry.roiPath; %#ok<AGROW>
        roiNames(end + 1, 1) = entry.name; %#ok<AGROW>
    end
end

macroPath = string(tempname) + ".ijm";

try
    write_macro(macroPath, imagePath, roiPaths, roiNames);
catch ME
    obj.setError("Could not write the Fiji macro: %s", ME.message);
    uialert(obj.Fig, "Could not write the macro Fiji is started with:" + newline ...
        + ME.message, "Fiji Failed");
    return
end

try
    launch_fiji(fijiPath, macroPath);
catch ME
    obj.setError("Could not start Fiji: %s", ME.message);
    uialert(obj.Fig, "Could not start Fiji from:" + newline + fijiPath + newline ...
        + newline + ME.message, "Fiji Failed");
    return
end

[~, name, ext] = fileparts(imagePath);

if obj.isEditingRow(row) && obj.RoiEditDirty
    obj.setWarning("Opening %s in Fiji. The ROI being edited is not saved, " ...
        + "so Fiji shows the line on disk.", name + ext);
else
    obj.setSuccess("Opening %s in Fiji with %d ROI(s).", name + ext, numel(roiPaths));
end

end

function fijiPath = locate_fiji(obj)
%LOCATE_FIJI Find the Fiji launcher, asking for it only when it cannot be found.
% The remembered launcher is used while it still exists. After that the usual
% install folders are searched, and only then is the user asked, so a Fiji
% that was moved or updated is found again without a dialog when it can be.

fijiPath = obj.FijiPath;

if fijiPath ~= "" && isfile(fijiPath)
    return
end

fijiPath = search_fiji();

if fijiPath == ""
    fijiPath = pick_fiji(obj);
end

if fijiPath ~= ""
    obj.FijiPath = fijiPath;
end

end

function fijiPath = search_fiji()
%SEARCH_FIJI Look for a Fiji launcher in the folders Fiji is usually unpacked to.
% The newer launcher is preferred to the older one where a Fiji.app has both,
% which every Fiji updated since 2025 does. Folders on the system path are
% searched too, both for a launcher sitting in one and for a Fiji.app unpacked
% into one, since a folder of programs put on the path is a common home for it.

fijiPath = "";

home = string(char(java.lang.System.getProperty("user.home")));
onPath = split(string(getenv("PATH")), pathsep);
onPath = onPath(onPath ~= "");

if ispc
    roots = [ ...
        fullfile(home, ["", "Desktop", "Documents", "Downloads"]), ...
        string(getenv("LOCALAPPDATA")), ...
        "C:\", string(getenv("ProgramFiles")), onPath(:)'];
    apps = [fullfile(roots, "Fiji.app"), onPath(:)'];
    names = ["fiji-windows-x64.exe", "ImageJ-win64.exe"];
elseif ismac
    apps = fullfile(["/Applications", fullfile(home, "Applications")], ...
        "Fiji.app", "Contents", "MacOS");
    names = ["fiji-macos-arm64", "fiji-macos-x64", "fiji-macos-universal", "ImageJ-macosx"];
else
    roots = [home, fullfile(home, "Applications"), "/opt", onPath(:)'];
    apps = [fullfile(roots, "Fiji.app"), onPath(:)'];
    names = ["fiji-linux-x64", "fiji-linux-arm64", "ImageJ-linux64"];
end

for iApp = 1:numel(apps)
    for iName = 1:numel(names)
        candidate = fullfile(apps(iApp), names(iName));

        if isfile(candidate)
            fijiPath = candidate;
            return
        end
    end
end

end

function fijiPath = pick_fiji(obj)
%PICK_FIJI Ask the user to point at the Fiji launcher.

fijiPath = "";

if ispc
    filter = {'*.exe', 'Fiji launcher (*.exe)'};
else
    filter = {'*', 'Fiji launcher'};
end

[file, folder] = uigetfile(filter, ...
    "Locate the Fiji launcher, e.g. Fiji.app\fiji-windows-x64.exe");

% UIGETFILE can leave the app figure behind whatever window was in front.
figure(obj.Fig);

if isequal(file, 0)
    return
end

fijiPath = string(fullfile(folder, file));

end

function write_macro(macroPath, imagePath, roiPaths, roiNames)
%WRITE_MACRO Write the macro that opens the image and lays its ROIs over it.

lines = "open(" + macro_string(imagePath) + ");";

if ~isempty(roiPaths)
    lines(end + 1) = "id = getImageID();";

    for iRoi = 1:numel(roiPaths)
        lines(end + 1) = "selectImage(id);"; %#ok<AGROW>
        lines(end + 1) = "open(" + macro_string(roiPaths(iRoi)) + ");"; %#ok<AGROW>
        lines(end + 1) = "Roi.setName(" + macro_string(roiNames(iRoi)) + ");"; %#ok<AGROW>
        lines(end + 1) = "Overlay.addSelection;"; %#ok<AGROW>
    end

    % The last ROI is the active one. It stays on the overlay with the rest,
    % so its label shows, and is opened once more to leave it as the
    % selection, since adding a selection to the overlay may clear it.
    lines(end + 1) = "Overlay.useNamesAsLabels(true);";
    lines(end + 1) = "Overlay.drawLabels(true);";
    lines(end + 1) = "Overlay.show;";
    lines(end + 1) = "open(" + macro_string(roiPaths(end)) + ");";
    lines(end + 1) = "Roi.setName(" + macro_string(roiNames(end)) + ");";
end

writelines(lines, macroPath);

end

function s = macro_string(value)
%MACRO_STRING Quote a value as an ImageJ macro string literal.
% Forward slashes are what ImageJ reads a path in on every platform, and they
% save escaping every backslash in a Windows path.

value = replace(string(value), "\", "/");
value = replace(value, """", "\""");
s = """" + value + """";

end

function launch_fiji(fijiPath, macroPath)
%LAUNCH_FIJI Start Fiji on the macro without waiting for it to close.

if ispc
    % START returns at once and opens no console window; the empty title is
    % there because START takes its first quoted argument as one.
    command = sprintf('start "" "%s" -macro "%s"', fijiPath, macroPath);
else
    command = sprintf('"%s" -macro "%s" > /dev/null 2>&1 &', fijiPath, macroPath);
end

[status, output] = system(command);

if status ~= 0
    error("HistologyImageBrowser:FijiFailed", "%s", strtrim(output));
end

end
