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
display.Meas = measured_marks(obj.View);
display.Prof = obj.View.NProfiles;
display.Images = obj.View.Variants;
display.Status = obj.View.Status;

obj.CatalogTable.Data = display;
obj.CatalogTable.ColumnWidth = {70, 60, 45, 70, 45, 40, 40, "auto", "auto"};

% Selecting the first match keeps a filtered lookup one click from a picture.
obj.CatalogTable.Selection = 1;
obj.CountLabel.Text = describe_counts(obj);
obj.onSelectionChanged();

end

function marks = measured_marks(View)
%MEASURED_MARKS Render the measured flag as a column that stays narrow.
% A tick and a blank, rather than yes and no, because the column is there to be
% scanned down while working through a stack of sections: what matters is which
% rows are still outstanding, and blanks show that at a glance.

if ~ismember("Measured", string(View.Properties.VariableNames))
    marks = strings(height(View), 1);
    return
end

marks = strings(height(View), 1);
marks(logical(View.Measured)) = char(10003);

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
