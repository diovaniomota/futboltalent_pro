import { getDocument } from 'pdfjs-dist/build/pdf.mjs';

async function extractText() {
  const doc = await getDocument('C:\\Users\\diova\\Downloads\\FutbolTalent - testing 30_3.pdf').promise;
  let fullText = '';
  for (let i = 1; i <= doc.numPages; i++) {
    const page = await doc.getPage(i);
    const content = await page.getTextContent();
    const strings = content.items.map(item => item.str);
    fullText += strings.join(' ') + '\n\n--- PAGE ' + i + ' END ---\n\n';
  }
  console.log(fullText);
}

extractText().catch(console.error);
