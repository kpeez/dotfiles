# Pass everything through to npx unchanged; when npx was used to install
# agent skills (`npx skills add ...` and friends), record any new skills in
# ~/.dotfiles/agent-config/skills.json and commit the manifest. The push
# happens on the next `mise run sync`.
function npx --description 'npx; auto-record agent skills installed via npx skills in agent-config/skills.json'
    command npx $argv
    set -l rc $status
    if test $rc -eq 0
        set -l i 1
        while test $i -le (count $argv); and string match -q -- '-*' "$argv[$i]"
            set i (math $i + 1)
        end
        if test $i -lt (count $argv); and string match -rq -- '^skills(@.+)?$' "$argv[$i]"
            set -l next (math $i + 1)
            switch "$argv[$next]"
                case add update install experimental_install
                    nu ~/.dotfiles/scripts/skills.nu record-commit
            end
        end
    end
    return $rc
end
