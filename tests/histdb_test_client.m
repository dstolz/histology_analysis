function [fake, restore, top] = histdb_test_client(opts)
%HISTDB_TEST_CLIENT The lab database client set up for a test: fake server, temporary everything.
%   [fake, restore, top] = histdb_test_client()
%   [...] = histdb_test_client(Enabled = false)
%
% A temporary preference store, a fake password vault, a temporary client
% folder, no sending timer, and labclient.FakeBackend standing in for the
% server, with storage root "nas" mapped to the new folder TOP and the
% subjects SUBJ-1 and SUBJ-2. RESTORE is a cell of cleanup objects: clear
% them in reverse order to put everything back. Needs the labclient package.
%
% See also HISTDBCLIENTTEST, HISTDBINVARIANCETEST.

arguments
    opts.Enabled (1,1) logical = true
end

restore = {labclient.Prefs.useTemporary(), labclient.Secrets.useFake(), ...
    labclient.DB.useTemporary(), labclient.Sync.useManual()};
fake = labclient.FakeBackend();
fake.Roots = table(1, "nas", "the lab's NAS", VariableNames = ["root_id", "name", "description"]);
fake.Subjects = table(["SUBJ-1"; "SUBJ-2"], ["P1"; "P1"], ["meriones_unguiculatus"; "meriones_unguiculatus"], ...
    ["F"; "M"], VariableNames = ["subject_id", "project_id", "species_code", "sex"]);
f = fake;
restore{end + 1} = labclient.DB.useBackend(@() f);
top = string(tempname);
mkdir(top);
s = labclient.Settings.defaults();
s.Enabled = opts.Enabled;
s.Server = "labdb.test";
s.Username = "jdoe";
s.Roots = struct("Name", "nas", "Path", top);
labclient.Settings.save(s);
labclient.Secrets.setFake(labclient.Settings.load(), fake.Password);
end
