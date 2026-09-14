function onEditFilenamePattern(obj)
%ONEDITFILENAMEPATTERN Edit how filenames are read into tokens, with a preview.
% The naming convention this toolbox was written around belongs to one lab.
% Anyone whose filenames differ gets a catalog of bare stems and no filters,
% and until now had no way to say so. This is where they say so.
%
% The table under the editor is the whole point of the dialog. A pattern is
% judged by what it pulls out of the names that are actually on disk, so the
% preview parses the loaded dataset through PARSE_HISTOLOGY_FILENAME itself and
% redraws on every keystroke. A pattern that matches nothing is then obvious
% while it is being written, instead of after a load that produced an empty
% catalog. Previewing a canned example instead was rejected for exactly that
% reason: it would prove the syntax works and say nothing about whether it
% works here.
%
% Two ways of describing a scheme are offered because two kinds of user need
% one. A regular expression says everything, and a token list, a delimiter plus
% the field names in order, says the common thing without asking anyone to
% learn regular expressions. The token list compiles into a pattern rather than
% being stored as a scheme of its own, so what leaves this dialog is one kind
% of thing no matter which row it was written in.
%
% See also APPLYFILENAMEPATTERN, CHECKFILENAMEPATTERN, TOKENLISTPATTERN,
% FILENAMEPATTERNPREVIEW, FILENAMEPATTERNSAMPLES, PARSE_HISTOLOGY_FILENAME.

[sampleNames, sampleSource] = obj.filenamePatternSamples();

state = struct( ...
    mode = "builtin", ...
    regexText = "", ...
    delimiter = "_", ...
    tokens = "", ...
    pattern = "");

if obj.FilenamePattern ~= ""
    state.mode = "regex";
    state.regexText = obj.FilenamePattern;
end

% Cancel is what a closed window means, so the outcome is held here and the
% close request writes to it exactly as the button does.
outcome = struct(accepted = false, pattern = obj.FilenamePattern);

dlg = uifigure( ...
    Name = "Filename Pattern", ...
    Position = center_on(obj.Fig, [920 640]));

% A release that will not make a uifigure modal still shows the dialog; the
% wait below is what actually holds the caller either way.
try
    dlg.WindowStyle = "modal";
catch
end

grid = uigridlayout(dlg, [7 4]);
grid.RowHeight = {"fit", "fit", "fit", "fit", "fit", "1x", "fit"};
grid.ColumnWidth = {"fit", "1x", 130, 130};
grid.Padding = [10 10 10 10];

intro = uilabel(grid, Text = intro_text(), WordWrap = "on");
intro.Layout.Row = 1;
intro.Layout.Column = [1 4];

modeLabel = uilabel(grid, Text = "Describe names by");
modeLabel.Layout.Row = 2;
modeLabel.Layout.Column = 1;

modeDropDown = uidropdown(grid, ...
    Items = [ ...
        "the built-in convention (default)", ...
        "a regular expression with named tokens", ...
        "a list of token names split on a delimiter"], ...
    ItemsData = ["builtin", "regex", "tokens"], ...
    Value = state.mode, ...
    ValueChangedFcn = @(src, ~) change_mode(string(src.Value)));
modeDropDown.Layout.Row = 2;
modeDropDown.Layout.Column = [2 4];

patternLabel = uilabel(grid, Text = "Pattern");
patternLabel.Layout.Row = 3;
patternLabel.Layout.Column = 1;

% ValueChangingFcn is what makes the preview live; ValueChangedFcn catches the
% paste-and-tab that never fires a keystroke.
patternField = uieditfield(grid, "text", ...
    Value = state.regexText, ...
    Placeholder = "^(?<SubjectID>[^_]+)_(?<SectionID>[^_]+)_ ... $", ...
    ValueChangingFcn = @(~, evt) set_regex(string(evt.Value)), ...
    ValueChangedFcn = @(src, ~) set_regex(string(src.Value)));
patternField.FontName = "Consolas";
patternField.Layout.Row = 3;
patternField.Layout.Column = [2 4];

tokenGrid = uigridlayout(grid, [1 4]);
tokenGrid.RowHeight = {"fit"};
tokenGrid.ColumnWidth = {"fit", 70, "fit", "1x"};
tokenGrid.Padding = [0 0 0 0];
tokenGrid.Layout.Row = 4;
tokenGrid.Layout.Column = [1 4];

uilabel(tokenGrid, Text = "Delimiter");

delimiterField = uieditfield(tokenGrid, "text", ...
    Value = state.delimiter, ...
    ValueChangingFcn = @(~, evt) set_delimiter(string(evt.Value)), ...
    ValueChangedFcn = @(src, ~) set_delimiter(string(src.Value)));

uilabel(tokenGrid, Text = "Token names");

tokenField = uieditfield(tokenGrid, "text", ...
    Value = state.tokens, ...
    Placeholder = "SubjectID, SectionID, -, Stain      (a dash ignores that field)", ...
    ValueChangingFcn = @(~, evt) set_tokens(string(evt.Value)), ...
    ValueChangedFcn = @(src, ~) set_tokens(string(src.Value)));

messageLabel = uilabel(grid, Text = "", WordWrap = "on");
messageLabel.Layout.Row = 5;
messageLabel.Layout.Column = [1 4];

previewTable = uitable(grid);
previewTable.Layout.Row = 6;
previewTable.Layout.Column = [1 4];

% Putting it back is the one thing a user in trouble looks for by name rather
% than by finding it in a list, so it is a button as well as the first row of
% the dropdown it sets.
restoreButton = uibutton(grid, "push", Text = "Restore Default", ...
    ButtonPushedFcn = @(~, ~) restore_default());
restoreButton.Layout.Row = 7;
restoreButton.Layout.Column = 1;

cancelButton = uibutton(grid, "push", Text = "Cancel", ...
    ButtonPushedFcn = @(~, ~) finish(false));
cancelButton.Layout.Row = 7;
cancelButton.Layout.Column = 3;

applyButton = uibutton(grid, "push", Text = "Apply", ...
    ButtonPushedFcn = @(~, ~) finish(true));
applyButton.Layout.Row = 7;
applyButton.Layout.Column = 4;

dlg.CloseRequestFcn = @(~, ~) finish(false);

apply_mode();

uiwait(dlg);

if ~outcome.accepted
    obj.setStatus("Filename pattern left unchanged.");
    return
end

obj.applyFilenamePattern(outcome.pattern);

    function change_mode(newMode)
        %CHANGE_MODE Switch which of the two editors describes the scheme.

        state.mode = newMode;
        apply_mode();
    end

    function apply_mode()
        %APPLY_MODE Enable the editor the current mode uses, and seed it.
        % Coming into the regular expression editor empty-handed seeds the
        % built-in convention written out as one. It is the only starting point
        % that is both correct and worth editing, and an empty box teaches the
        % syntax to nobody.

        if state.mode == "regex" && strtrim(state.regexText) == ""
            state.regexText = HistologyImageBrowser.DefaultFilenamePattern;
        end

        if state.mode == "regex"
            patternField.Value = state.regexText;
        end

        patternField.Enable = matlab.lang.OnOffSwitchState(state.mode ~= "builtin");
        patternField.Editable = matlab.lang.OnOffSwitchState(state.mode == "regex");
        delimiterField.Enable = matlab.lang.OnOffSwitchState(state.mode == "tokens");
        tokenField.Enable = matlab.lang.OnOffSwitchState(state.mode == "tokens");

        refresh();
    end

    function restore_default()
        %RESTORE_DEFAULT Go back to the convention the toolbox ships with.

        state.mode = "builtin";
        modeDropDown.Value = "builtin";
        apply_mode();
    end

    function set_regex(text)
        %SET_REGEX Take the pattern being typed and redraw the preview.

        state.regexText = text;
        refresh();
    end

    function set_delimiter(text)
        %SET_DELIMITER Take the delimiter being typed and redraw the preview.

        state.delimiter = text;
        refresh();
    end

    function set_tokens(text)
        %SET_TOKENS Take the token names being typed and redraw the preview.

        state.tokens = text;
        refresh();
    end

    function refresh()
        %REFRESH Recompute the pattern, judge it, and redraw the preview table.
        % The compiled pattern is written back into the pattern field in token
        % mode so the two forms are visibly the same thing, but never in
        % regular expression mode, where the field is what is being typed into
        % and writing to it would move the caret.

        switch state.mode
            case "builtin"
                state.pattern = "";
                patternField.Value = "";

            case "regex"
                state.pattern = strtrim(state.regexText);

            otherwise
                state.pattern = HistologyImageBrowser.tokenListPattern( ...
                    state.delimiter, state.tokens);
                patternField.Value = state.pattern;
        end

        [usable, why] = HistologyImageBrowser.checkFilenamePattern(state.pattern);

        if usable && state.mode == "tokens"
            [usable, why] = check_token_names(state.tokens);
        end

        applyButton.Enable = matlab.lang.OnOffSwitchState(usable);

        if ~usable
            previewTable.Data = HistologyImageBrowser.filenamePatternPreview(strings(0, 1));
            messageLabel.FontColor = [0.60 0.05 0.05];
            messageLabel.Text = "This pattern cannot be used: " + why + ".";

            return
        end

        T = HistologyImageBrowser.filenamePatternPreview(sampleNames, state.pattern);

        previewTable.Data = T;
        messageLabel.FontColor = [0.15 0.15 0.15];
        messageLabel.Text = match_summary(T, sampleSource);
    end

    function finish(accepted)
        %FINISH Record the choice and release the wait.

        outcome.accepted = accepted;
        outcome.pattern = state.pattern;

        delete(dlg);
    end

end

function text = intro_text()
%INTRO_TEXT Say what the pattern decides, and what it is not responsible for.
% The marker paragraph is here because the first pattern anyone writes ends in
% _proj, and nothing about an empty table explains why that cannot match.

text = "Filenames are read into named tokens before they are cataloged. The " + ...
    "built-in convention is " + ...
    "SUBJ-ID-<n><SampleID>_<Section>_<Hemi>_<Stain>_<Z>_<Date>_<ImageNumber>." + ...
    newline + newline + ...
    "The _proj, _mid, _composite, _roi and _values suffixes written by the Fiji " + ...
    "macro are always removed before the pattern runs and are never part of it, " + ...
    "so write the pattern against the Stem column below. Tokens named SubjectID, " + ...
    "SampleID, SectionID, Hemisphere, Stain, ZPlane, DateCode, ImageNumber, " + ...
    "Protocol or Series become catalog columns; any other token is extracted and " + ...
    "shown here but is not cataloged. Nothing is re-read until the dataset is " + ...
    "loaded again.";

end

function [usable, why] = check_token_names(tokens)
%CHECK_TOKEN_NAMES Judge a token list by its names rather than by its pattern.
% A name that cannot be a capture group name makes the compiled pattern fail to
% compile, and the message REGEXP gives for that names a character position in
% generated text the user never saw. Naming the offending token instead is the
% only version of that message anyone can act on.

usable = true;
why = "";

names = strtrim(split(string(tokens), ","));

for iName = 1:numel(names)
    thisName = names(iName);

    if thisName == "" || thisName == "-" || isvarname(thisName)
        continue
    end

    usable = false;
    why = """" + thisName + """ cannot be a token name; use letters, digits and " + ...
        "underscores, starting with a letter, or a dash to ignore the field";

    return
end

end

function text = match_summary(T, source)
%MATCH_SUMMARY Report how far the pattern got, and against what.
% Saying which names are being previewed matters most when they are not the
% ones on disk: a pattern that matches every example and none of the real files
% is a result that has to be tellable apart from success.

nNames = height(T);
nMatched = sum(T.Match == "yes");

text = sprintf("%d of %d name(s) matched.", nMatched, nNames);

if source == "dataset"
    text = text + " Previewing filenames from the loaded dataset.";

    return
end

text = text + " No dataset is loaded, so these are example names, including two " + ...
    "in other conventions. Load a dataset to preview your own.";

end

function position = center_on(parent, size)
%CENTER_ON Place a dialog over the window it belongs to.
% A dialog that opens on the primary monitor while the app sits on a second one
% is easy to miss entirely. ONREPORTISSUE places its own dialog the same way.

position = [100 100 size];

if isempty(parent) || ~isvalid(parent)
    return
end

anchor = parent.Position;
position(1:2) = anchor(1:2) + (anchor(3:4) - size) / 2;

end
