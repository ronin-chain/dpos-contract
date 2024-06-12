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

    if (typeof jsonData.storageLayout == 'undefined') return;
    if (jsonData.storageLayout.storage.length == 0) return;

    const hasAst = typeof jsonData.ast != 'undefined';

    let storageLayout;
    if (hasAst) {
      const absolutePath = jsonData.ast.absolutePath;
      if (typeof absolutePath == 'undefined') return;
      if (!absolutePath.startsWith('src')) return;

      storageLayout = jsonData.storageLayout.storage;
    } else {
      // filter only contracts in src/*
      storageLayout = jsonData.storageLayout.storage.filter(({ contract }) =>
        contract.startsWith('src')
      );
    }

    const outputData = storageLayout
      .map(({ contract, label, offset, slot, type: typeId }) => {
        const typeObj = jsonData.storageLayout.types[typeId];
        const typeLabel = typeObj.label;
        const numberOfBytes = typeObj.numberOfBytes;
        return `${contract}:${label} (storage_slot: ${slot}) (offset: ${offset}) (type: ${typeLabel}) (numberOfBytes: ${numberOfBytes})`;
      })
      .join('\n');

    if (outputData == '') return;

    if (!fileOut) {
      console.log(outputData);
    } else {
      fs.writeFile(fileOut, outputData, 'utf-8', (err) => {
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