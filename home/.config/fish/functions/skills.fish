# Run the skills CLI, then record any new skills in
# ~/.dotfiles/agent-config/skills.json and commit the manifest. The push
# happens on the next `mise run sync`.
function skills --description 'Run the skills CLI and auto-record installed skills in agent-config/skills.json'
    command skills $argv
    set -l rc $status
    if test $rc -eq 0
        switch "$argv[1]"
            case add update install experimental_install
                nu ~/.dotfiles/scripts/skills.nu record-commit
        end
    end
    return $rc
end
