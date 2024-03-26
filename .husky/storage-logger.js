const fs = require('fs');
const fileIn = process.argv[2];
const fileOut = process.argv[3];

if (!fileIn) {
  console.error('Invalid input');
}

fs.readFile(fileIn, 'utf8', (err, data) => {
  if (err) {
    console.error('Error reading file:', err);
    return;
  }

  try {
    const jsonData = JSON.parse(data);
    if (typeof jsonData.storageLayout == 'undefined' || jsonData.ast.absolutePath == 'undefined') {
      return;
    }

    if (jsonData.storageLayout.storage.length == 0) {
      return;
    }

    // Skip generating storage layout for files locate in the directory "src"
    if (!jsonData.ast.absolutePath.startsWith('src')) {
      return;
    }

    const outputData = jsonData.storageLayout.storage
      .map(({ contract, label, offset, slot, type: typeId }) => {
        const typeObj = jsonData.storageLayout.types[typeId];
        const typeLabel = typeObj.label;
        const numberOfBytes = typeObj.numberOfBytes;
        return `${contract}:${label} (storage_slot: ${slot}) (offset: ${offset}) (type: ${typeLabel}) (numberOfBytes: ${numberOfBytes})`;
      })
      .join('\n');
    if (!fileOut) {
      console.log(outputData);
    } else {
      fs.writeFile(fileOut, outputData, 'utf-8', err => {
        if (err) {
          console.error('Error writing file:', err);
          return;
        }
      });
    }
  } catch (err) {
    console.error('Error parsing JSON:', err);
  }
});