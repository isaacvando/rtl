#!/usr/bin/env sh

roc build ../rtl.roc
../rtl
roc output.roc > output.txt

exit_code=0
if ! diff "output.txt" "expectedOutput.txt"; then
    exit_code=1
fi

if ! diff "Pages.roc" "ExpectedPages.roc"; then
    exit_code=1
fi

if [ $exit_code -eq 0 ]; then
    echo "All snapshots passed ✨"
else
    echo "Some snapshots failed ✋"
fi

exit $exit_code
