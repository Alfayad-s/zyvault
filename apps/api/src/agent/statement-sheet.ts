import * as XLSX from 'xlsx';

/** First worksheets of an Excel statement, as tab-separated text. */
export function xlsxStatement(data: Uint8Array): string {
  const book = XLSX.read(data, { type: 'array', cellDates: true });
  return book.SheetNames.map((name) => sheetText(book.Sheets[name])).filter(Boolean).join('\n');
}

function sheetText(sheet: XLSX.WorkSheet | undefined): string {
  if (!sheet?.['!ref']) return '';
  const range = XLSX.utils.decode_range(sheet['!ref']);
  const lines: string[] = [];
  for (let row = range.s.r; row <= range.e.r; row++) {
    const cells: string[] = [];
    let filled = false;
    for (let column = range.s.c; column <= range.e.c; column++) {
      const text = cellText(sheet[XLSX.utils.encode_cell({ r: row, c: column })]);
      if (text) filled = true;
      cells.push(text);
    }
    if (filled) lines.push(cells.join('\t'));
  }
  return lines.join('\n');
}

function cellText(cell: XLSX.CellObject | undefined): string {
  if (!cell || cell.v == null) return '';
  if (cell.v instanceof Date) {
    const format = String(cell.z ?? '').toLowerCase();
    if (format.startsWith('d') && typeof cell.w === 'string' && /\d/.test(cell.w)) return cell.w.trim();
    return dayMonthYear(cell.v);
  }
  if (typeof cell.v === 'number') return Number.isInteger(cell.v) ? String(cell.v) : cell.v.toFixed(2);
  return String(cell.v).replace(/[\t\r\n]+/g, ' ').trim();
}

/** Excel date objects are local midnights, which sit on the previous UTC day in India. */
function dayMonthYear(date: Date): string {
  const shifted = new Date(date.getTime() + 12 * 60 * 60 * 1000);
  const day = String(shifted.getUTCDate()).padStart(2, '0');
  const month = String(shifted.getUTCMonth() + 1).padStart(2, '0');
  return `${day}/${month}/${shifted.getUTCFullYear()}`;
}
