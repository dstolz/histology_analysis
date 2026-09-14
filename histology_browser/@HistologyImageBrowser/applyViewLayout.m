function applyViewLayout(obj)
%APPLYVIEWLAYOUT Place the image and profile panels for the chosen layout.
% The profile plot can sit below, above, left of, or right of the image
% tiles, or take over the view entirely, or be hidden. Profile size sets the
% share of the split dimension the profile plot receives.

layout = obj.profileLayout();
profileShare = profile_share(obj);

% Grow to the full 2x2 grid before moving anything, so a panel is never
% assigned to a row or column the grid does not have yet.
obj.ViewGrid.RowHeight = {"1x", "1x"};
obj.ViewGrid.ColumnWidth = {"1x", "1x"};

imageWeight = weight(1 - profileShare);
profileWeight = weight(profileShare);

switch layout
    case "top"
        place(obj.ProfilePanel, 1, 1);
        place(obj.ImagePanel, 2, 1);
        rowHeight = {profileWeight, imageWeight};
        columnWidth = {"1x"};

    case "left"
        place(obj.ProfilePanel, 1, 1);
        place(obj.ImagePanel, 1, 2);
        rowHeight = {"1x"};
        columnWidth = {profileWeight, imageWeight};

    case "right"
        place(obj.ImagePanel, 1, 1);
        place(obj.ProfilePanel, 1, 2);
        rowHeight = {"1x"};
        columnWidth = {imageWeight, profileWeight};

    case {"hidden", "only"}
        % One panel fills the view and the other is switched off; both can
        % share the single cell because only one of them is visible.
        place(obj.ImagePanel, 1, 1);
        place(obj.ProfilePanel, 1, 1);
        rowHeight = {"1x"};
        columnWidth = {"1x"};

    otherwise   % "bottom"
        place(obj.ImagePanel, 1, 1);
        place(obj.ProfilePanel, 2, 1);
        rowHeight = {imageWeight, profileWeight};
        columnWidth = {"1x"};
end

obj.ViewGrid.RowHeight = rowHeight;
obj.ViewGrid.ColumnWidth = columnWidth;

obj.ImagePanel.Visible = on_off(obj.showImages());
obj.ProfilePanel.Visible = on_off(obj.showProfile());

% The size control only means something when the view is actually split.
obj.ProfileSizeField.Enable = on_off(obj.showImages() && obj.showProfile());

% The normalizations mean nothing when the plot they rescale is not on screen,
% which is the half of their enable state this function is the one to know.
obj.updateProfileControls();

end

function place(panel, row, column)
%PLACE Assign an explicit grid position to a panel.

panel.Layout.Row = row;
panel.Layout.Column = column;

end

function share = profile_share(obj)
%PROFILE_SHARE Fraction of the split dimension given to the profile plot.

share = 1 / 3;

if isempty(obj.ProfileSizeField) || ~isvalid(obj.ProfileSizeField)
    return
end

value = obj.ProfileSizeField.Value;

if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
    return
end

share = min(max(value / 100, 0.05), 0.95);

end

function w = weight(fraction)
%WEIGHT Format a grid weight, keeping a floor so neither panel collapses.

w = sprintf("%.4gx", max(fraction, 0.05));

end

function state = on_off(tf)
%ON_OFF Convert a logical to the matlab.lang.OnOffSwitchState text.

if tf
    state = "on";
else
    state = "off";
end

end
