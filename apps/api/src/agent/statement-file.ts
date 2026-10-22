import { extractText, extractTextItems, getDocumentProxy } from 'unpdf';
import { rowsFromSbiLayout, type StatementRow } from './statement.js';

export class StatementLocked extends Error {
  constructor(readonly wrong: boolean) {
    super(wrong ? 'That password did not open the statement' : 'That statement is locked');
  }
}

/** Text layer of a PDF, plus SBI table rows when the pages use that column layout. */
export async function pdfStatement(
  data: Uint8Array,
  password?: string,
): Promise<{ text: string; pages: number; rows: StatementRow[] | null }> {
  let pdf: Awaited<ReturnType<typeof getDocumentProxy>>;
  try {
    pdf = await getDocumentProxy(data, password ? { password } : undefined);
  } catch (caught) {
    if (needsPassword(caught)) throw new StatementLocked(Boolean(password));
    throw caught;
  }
  let pages = pdf.numPages;
  try {
    const positioned = await extractTextItems(pdf);
    pages = positioned.totalPages || pages;
    const rows = rowsFromSbiLayout(positioned.items);
    if (rows) return { text: '', pages, rows };
  } catch (caught) {
    if (needsPassword(caught)) throw new StatementLocked(Boolean(password));
  }
  try {
    const extracted = await extractText(pdf, { mergePages: true });
    return { text: extracted.text.trim(), pages: extracted.totalPages, rows: null };
  } catch (caught) {
    if (needsPassword(caught)) throw new StatementLocked(Boolean(password));
    return { text: '', pages, rows: null };
  }
}

export function needsPassword(caught: unknown): boolean {
  if (!caught || typeof caught !== 'object') return false;
  const error = caught as { name?: string; code?: number; message?: string };
  return error.name === 'PasswordException' || error.code === 1 || error.code === 2 || /password/i.test(error.message ?? '');
}
