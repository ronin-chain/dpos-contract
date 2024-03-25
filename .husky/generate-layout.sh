#!/bin/sh

rm -rf logs/storage/*
dirOutputs=$(ls out | grep '^[^.]*\.sol$') # assuming the out dir is at 'out'
while IFS= read -r contractDir; do
  innerdirOutputs=$(ls out/$contractDir)

  while IFS= read -r jsonFile; do
    fileIn=out/$contractDir/$jsonFile
    fileOut=logs/storage/$contractDir:${jsonFile%.json}.log
    node .husky/storage-logger.js $fileIn $fileOut &
  done <<< "$innerdirOutputs"
done <<< "$dirOutputs"

# Wait for all background jobs to finish
wait