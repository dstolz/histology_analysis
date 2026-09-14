function tf = applyFilenamePattern(obj, pattern, options)
%APPLYFILENAMEPATTERN Adopt a filename pattern, or refuse it and say why.
% Kept apart from ONEDITFILENAMEPATTERN so the pattern can be set, validated,
% and persisted without a dialog opening: the dialog is one caller, restoring
% the preference at startup is another, and a test that had to drive a modal
% window to check the wiring would be a test that hangs.
%
% Nothing is re-cataloged here. The pattern decides how thousands of filenames
% are read, and rebuilding the catalog behind the user as a side effect of an
% Apply would throw away the current selection and any unsaved ROI edit; the
% tracker CSV is chosen the same way and says the same thing, so the two read
% alike.
%
% Parameters
%   pattern: Named-capture pattern, or "" for the built-in convention.
%   options.persist: Write the choice to preferences and announce it. False on
%       the startup path, which is restoring a choice already made rather than
%       making one, so it neither writes back what it just read nor puts a
%       message about it on a status bar the user has not looked at yet.
%
% Returns
%   tf: True when the pattern was adopted.
%
% See also ONEDITFILENAMEPATTERN, CHECKFILENAMEPATTERN, LOADPREFERENCES,
% SAVEPREFERENCES, ONLOADDATA.

arguments
    obj
    pattern (1,1) string = ""
    options.persist (1,1) logical = true
end

pattern = strtrim(pattern);

[tf, message] = HistologyImageBrowser.checkFilenamePattern(pattern);

if ~tf
    obj.setError("Filename pattern not applied: %s.", message);
    return
end

obj.FilenamePattern = pattern;

refresh_menu(obj, pattern);

if ~options.persist
    return
end

obj.savePreferences();

if pattern == ""
    obj.setStatus("Filename pattern reset to the built-in convention. Load again to apply it.");
    return
end

obj.setSuccess("Filename pattern set. Load again to apply it.");

end

function refresh_menu(obj, pattern)
%REFRESH_MENU Say on the Dataset menu which convention is in force.
% The pattern itself is far too long for a menu item, and the dialog is one
% click away, so the item reports which of the two states it is in rather than
% trying to show the text.

if isempty(obj.FilenamePatternMenu) || ~isvalid(obj.FilenamePatternMenu)
    return
end

if pattern == ""
    label = "(built-in convention)";
else
    label = "(custom)";
end

obj.FilenamePatternMenu.Text = "Filename Pattern:  " + label;

end
