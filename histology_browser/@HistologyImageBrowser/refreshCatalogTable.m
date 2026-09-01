function refreshCatalogTable(obj)
%REFRESHCATALOGTABLE Push the filtered view into the table and update counts.
% What the rows look like belongs to CATALOGDISPLAYTABLE and putting them in
% the widget belongs to WRITECATALOGTABLE, because a sort and a column
% rearrangement both have to do the same thing without also resetting the
% selection and the counts the way a fresh filter does. What is left here is
% only the part that is particular to having just refiltered.

obj.writeCatalogTable();

if height(obj.View) == 0
    obj.Selection = [];
    obj.CountLabel.Text = describe_counts(obj);
    obj.renderSelection();

    % Said after the redraw, which reports on the (now empty) selection.
    if height(obj.Catalog) > 0
        obj.setWarning("No sections match the current filters.");
    end

    return
end

% Selecting the first match keeps a filtered lookup one click from a picture.
obj.CatalogTable.Selection = 1;
obj.CountLabel.Text = describe_counts(obj);
obj.onSelectionChanged();

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
