function refreshCatalogTable(obj)
%REFRESHCATALOGTABLE Push the filtered view into the table and update counts.

if height(obj.View) == 0
    obj.CatalogTable.Data = table();
    obj.Selection = [];
    obj.CountLabel.Text = describe_counts(obj);
    obj.renderSelection();

    % Said after the redraw, which reports on the (now empty) selection.
    if height(obj.Catalog) > 0
        obj.setWarning("No sections match the current filters.");
    end

    return
end

display = table();
display.Subject = shorten_subject(obj.View.SubjectID);
display.Section = obj.View.SectionID;
display.Hemi = obj.View.Hemisphere;
display.Stain = obj.View.Stain;
display.Plate = obj.View.AtlasPlate;

% Which regions a section was measured across, by name. This replaced a plain
% count of its profiles: the names say how many there are as well, and Status
% already distinguishes a section that has none.
display.ROIs = roi_names(obj);
display.Images = obj.View.Variants;
display.Status = obj.View.Status;

obj.CatalogTable.Data = display;
obj.CatalogTable.ColumnWidth = {70, 60, 45, 70, 45, 70, "auto", "auto"};

% Selecting the first match keeps a filtered lookup one click from a picture.
obj.CatalogTable.Selection = 1;
obj.CountLabel.Text = describe_counts(obj);
obj.onSelectionChanged();

end

function names = roi_names(obj)
%ROI_NAMES List each row's ROIs by name, for the table column.

names = strings(height(obj.View), 1);

for iRow = 1:height(obj.View)
    names(iRow) = obj.describeRoiList(obj.View(iRow, :));
end

end

function short = shorten_subject(subjectID)
%SHORTEN_SUBJECT Drop the shared SUBJ-ID- prefix so the column stays narrow.

short = replace(string(subjectID), "SUBJ-ID-", "");

end

function text = describe_counts(obj)
%DESCRIBE_COUNTS Summarize how many sections the filters kept.

nTotal = height(obj.Catalog);
nShown = height(obj.View);

if nTotal == 0
    text = "No dataset loaded.";
    return
end

text = sprintf("Showing %d of %d sections.", nShown, nTotal);

end
