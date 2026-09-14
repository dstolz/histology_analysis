function updateProfileControls(obj)
%UPDATEPROFILECONTROLS Enable the profile normalization controls that apply now.
%
% Two conditions, for two different reasons. A layout that hides the profile
% plot leaves all three settings with nothing to act on, so they go grey along
% with the profile size field beside them. And with the intensity axis left
% raw, there is nothing for a scope to be measured over, so that one dropdown
% goes grey on its own -- it is the setting most easily read as doing something
% by itself, and greying it says plainly that it qualifies the choice to its
% left rather than standing beside it.
%
% Called from APPLYVIEWLAYOUT, so the layout condition is applied wherever the
% layout settles, and from ONPROFILEOPTIONCHANGED for the other one.
%
% See also APPLYVIEWLAYOUT, ONPROFILEOPTIONCHANGED, SYNCDISPLAYMENU.

if isempty(obj.ProfileNormDropDown) || ~isvalid(obj.ProfileNormDropDown)
    return
end

shown = obj.showProfile();

obj.ProfileNormDropDown.Enable = on_off(shown);
obj.ProfileDistanceDropDown.Enable = on_off(shown);
obj.ProfileScopeDropDown.Enable = on_off(shown && obj.profileNorm() ~= "none");

end

function state = on_off(tf)
%ON_OFF Convert a logical to the matlab.lang.OnOffSwitchState text.

if tf
    state = "on";
else
    state = "off";
end

end
