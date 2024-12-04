#!/usr/bin/env sh
set -euo pipefail

roc build ../rtl.roc
../rtl
roc output.roc > output.txt

if [ "${1:-}" = "-u" ]; then
    cp output.txt expectedOutput.txt
    cp Pages.roc ExpectedPages.roc
    echo "Updated snapshots 🎉"
    exit 0
fi

exit_code=0
if ! git diff --no-index "output.txt" "expectedOutput.txt"; then
    exit_code=1
fi

if ! git diff --no-index "Pages.roc" "ExpectedPages.roc"; then
    exit_code=1
fi

if [ $exit_code -eq 0 ]; then
    echo "All snapshots passed ✨"
else
    echo "Some snapshots failed ✋"
    echo 'If all of the changes look correct, you can update the expected values by running `./test.sh -u` and committing the changes.'
fi

exit $exit_code
