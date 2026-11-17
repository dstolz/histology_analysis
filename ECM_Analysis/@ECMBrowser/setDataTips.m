function setDataTips(obj, fields)
    %SETDATATIPS Name FIELDS in the data tip beside the X and Y of a point.
    %   B.setDataTips("SubjectID")
    %   B.setDataTips(["SubjectID" "AtlasPlate"])
    %   B.setDataTips()  leaves a tip with its X and Y alone
    %
    % The same thing the Data tips menu does, reachable from a script.
    % A browser opens on the subject where the dataset has one.
    %
    % A curve of one section names that section's value of each field.
    % A curve over several -- a group mean -- names the value they share,
    % the values themselves where there are only a few, and how many
    % different ones where there are more. A summary of points names the
    % value of the section each point stands for.
    %
    % Takes effect on what is already drawn, in the browser and in any
    % figure popped out of it, without redrawing, so a zoom is left alone.
    %
    % See also SETTILING, SETFILTER.

    arguments
        obj
        fields (1,:) string = strings(1, 0)
    end

    unknown = fields(~ismember(fields, obj.tipChoices()));

    if ~isempty(unknown)
        error("ECMBrowser:UnknownTipField", ...
            "This dataset has no field to name in a data tip called: %s", ...
            strjoin(unknown, ", "))
    end

    obj.TipFields = reshape(unique(fields, "stable"), 1, []);
    obj.tickDataTips();
    obj.applyDataTips();

end
