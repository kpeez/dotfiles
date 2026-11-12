# Pass everything through to npx unchanged; when npx was used to install
# agent skills (`npx skills add ...` and friends), record any new skills in
# ~/.dotfiles/agent-config/skills.json and commit the manifest. The push
# happens on the next `mise run sync`.
function npx --description 'npx; auto-record agent skills installed via npx skills in agent-config/skills.json'
    command npx $argv
    set -l rc $status
    if test $rc -eq 0; and contains -- skills $argv
        if contains -- add $argv; or contains -- remove $argv; or contains -- update $argv; or contains -- install $argv
            nu ~/.dotfiles/scripts/skills.nu record-commit
        end
    end
    return $rc
end
