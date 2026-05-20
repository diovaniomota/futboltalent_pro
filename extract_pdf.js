const pdfjsLib = require('pdfjs-dist/legacy/build/pdf.js');
const fs = require('fs');

async function extractText() {
  const doc = await pdfjsLib.getDocument('C:\\Users\\diova\\Downloads\\FutbolTalent - testing 30_3.pdf').promise;
  let fullText = '';
  for (let i = 1; i <= doc.numPages; i++) {
    const page = await doc.getPage(i);
    const content = await page.getTextContent();
    const strings = content.items.map(item => item.str);
    fullText += strings.join(' ') + '\n\n--- PAGE ' + i + ' END ---\n\n';
  }
  fs.writeFileSync('pdf_content.txt', fullText, 'utf8');
  console.log('Done. Pages: ' + doc.numPages);
}

extractText().catch(console.error);
