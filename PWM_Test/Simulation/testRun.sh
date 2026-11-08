#!/bin/bash

for file in *.robot; do
	[ -e "$file" ] || continue
	echo "====================================================="
	echo "Running TestSuite: $file"
	echo "====================================================="

	renode-test "$file" || { echo "Suite $file Failed.. Aborting"; exit 1; }
done

echo "All Tests Passed"
