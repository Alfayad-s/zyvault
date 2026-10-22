import { billItems, linesFromWords, listedItems, shopVisit } from './bill-items.js';

describe('billItems', () => {
  it('lists each priced row and drops the total', () => {
    const items = billItems(['Store', 'Milk 40', 'Bread 30.00', 'Total 70'], '2026-10-20');
    expect(items.map((item) => [item.rawDescription, item.amount, item.merchant])).toEqual([
      ['milk', 4000, 'Store'],
      ['bread', 3000, 'Store'],
    ]);
  });

  it('pairs a name on one line with the price on the next', () => {
    const items = billItems(['MILK', '40.00', 'BROWN BREAD', '30.00', 'GRAND TOTAL', '70.00'], '2026-10-20');
    expect(items.map((item) => [item.rawDescription, item.amount])).toEqual([
      ['milk', 4000],
      ['brown bread', 3000],
    ]);
  });

  it('skips tax lines and uses the line total after the quantity', () => {
    const items = billItems(['2 x Milk 2 80.00', 'CGST 4.00', 'SGST 4.00'], '2026-10-20');
    expect(items.map((item) => [item.rawDescription, item.amount])).toEqual([['milk', 8000]]);
  });

  it('keeps the line value on a shop bill and skips the total and savings', () => {
    const items = billItems(
      [
        "MRUDUL'S EMPORIUM",
        'GSTIN 32AAAAA0000A1Z5',
        'PEARS SOFT FRESH 330499 1 20.00 180.00',
        'BATH SOAP 45.00',
        'YOUR SAVINGS Rs. 14.00',
        'NET BILL AMOUNT 184.00',
      ],
      '2026-10-20',
    );
    expect(items.map((item) => [item.rawDescription, item.amount])).toEqual([
      ['pears soft fresh', 18000],
      ['bath soap', 4500],
    ]);
    expect(items[0]?.merchant).toBe("MRUDUL'S EMPORIUM");
  });

  it('uses the newline text when the grouped rows swallowed the prices', () => {
    const items = listedItems(
      {
        lines: ["MRUDUL'S EMPORIUM GSTIN PEARS SOFT FRESH 180.00 NET BILL AMOUNT 180.00"],
        text: "MRUDUL'S EMPORIUM\nPEARS SOFT FRESH 180.00\nNET BILL AMOUNT 180.00",
      },
      '2026-10-20',
    );
    expect(items.map((item) => item.rawDescription)).toEqual(['pears soft fresh']);
  });

  it('reads the pears bill and leaves out the GST table and bill number', () => {
    const items = billItems(
      [
        'MK HOME NEEDS',
        "Mrudul's Emporium, Near Chowdeshwari Temple",
        'Phone: 080-48519777, 9986585104',
        'GSTIN : 29AVFPM0224J1ZM',
        'TAX INVOICE',
        'Bill No : S/26-27/30963 Date : 20-10-2026',
        'UPI 01:22:58',
        'Sn Item Name Qty MRP Rate Amount',
        '1 PEARS SOFT N FRESH 1 199 180.0 180.00',
        'B WASH 250ML',
        'Total 1,000 180.00',
        'Net Bill Amount : ₹ 180.00',
        'Payment Details',
        'UPI 180.00',
        'Your Savings Rs. 19.00',
        'Taxable Value CGST SGST Total GST',
        '152.54 9.0 13.73 9.0 13.73 27.46',
        '152.54 13.73 13.73 27.46',
      ],
      '2026-10-20',
    );
    expect(items.map((item) => [item.rawDescription, item.amount])).toEqual([['pears soft n fresh b wash 250ml', 18000]]);
    expect(items[0]?.merchant).toBe('MK HOME NEEDS');
    expect(items[0]?.occurredOn).toBe('2026-10-20');
  });

  it('uses the shop name when the logo is split across lines', () => {
    const items = billItems(
      ['MK', 'OME', 'NEEDS', 'SUPERMARKET', "Mrudul's Emporium, Near Chowdeshwari Temple", 'PEARS SOFT N FRESH 180.00'],
      '2026-10-20',
    );
    expect(items[0]?.merchant).toBe("Mrudul's Emporium");
  });

  it('folds the items into one visit with the total', () => {
    const visit = shopVisit(
      billItems(['Store', 'Milk 40', 'Bread 30.00', 'Total 70'], '2026-10-20'),
    );
    expect([visit.merchant, visit.amount, visit.rawDescription]).toEqual(['Store', 7000, 'milk ₹40, bread ₹30']);
  });

  it('ignores the date, GPay line, and pin code on a shop bill', () => {
    const items = billItems(
      [
        "MRUDUL'S EMPORIUM",
        '20-10-2026 with Gpay 01:22:58 amount 180.00',
        'temple 560076 rate 180.00',
        'PEARS SOFT FRESH 330499 1 20.00 180.00',
        'CGST 13.73',
        'NET BILL AMOUNT 184.00',
      ],
      '2026-10-20',
    );
    expect(items.map((item) => [item.rawDescription, item.amount, item.merchant])).toEqual([
      ['pears soft fresh', 18000, "MRUDUL'S EMPORIUM"],
    ]);
    expect(items[0]?.occurredOn).toBe('2026-10-20');
  });

  it('reads a date printed on the bill', () => {
    const [item] = billItems(['Soap 25', 'Date 18/10/2026'], '2026-10-20');
    expect(item?.occurredOn).toBe('2026-10-18');
  });
});

describe('linesFromWords', () => {
  it('reads the product when the price sits on the following line', () => {
    const items = billItems(
      ['PEARS SOFT N FRESH', '1', '1 199 180.0 180.00', 'B WASH 250ML', 'Total', 'Net Bill Amount:', '180.00'],
      '2026-10-20',
    );
    expect(items.map((item) => [item.rawDescription, item.amount])).toEqual([['pears soft n fresh b wash 250ml', 18000]]);
  });

  it('keeps the product when the grouped rows are the tax table', () => {
    const items = listedItems(
      {
        lines: [
          'near deverchikkanahalli road qty 13.73',
          'main tax 30963',
          'emporium bommanahalli phone 26-27 name soft n 250ml total savings 9',
          'bill no pears b net your previous balance taxable value 152.54',
        ],
        text: ['PEARS SOFT N FRESH', '1', '1 199 180.0 180.00', 'B WASH 250ML', 'Total', 'Net Bill Amount:', '180.00'].join('\n'),
      },
      '2026-10-20',
    );
    expect(items.map((item) => [item.rawDescription, item.amount])).toEqual([['pears soft n fresh b wash 250ml', 18000]]);
  });

  it('joins words that share a row', () => {
    expect(
      linesFromWords([
        { text: 'Milk', x: 10, y: 40, height: 12 },
        { text: '40.00', x: 180, y: 42, height: 12 },
        { text: 'Bread', x: 12, y: 70, height: 12 },
        { text: '30.00', x: 180, y: 71, height: 12 },
      ]),
    ).toEqual(['Milk 40.00', 'Bread 30.00']);
  });

  it('joins a sideways photo along the receipt rows', () => {
    expect(
      linesFromWords([
        { text: 'Milk', x: 40, y: 10, height: 12, width: 28 },
        { text: '40.00', x: 42, y: 180, height: 12, width: 36 },
        { text: 'Bread', x: 70, y: 12, height: 12, width: 40 },
        { text: '30.00', x: 71, y: 180, height: 12, width: 36 },
      ]),
    ).toEqual(['Milk 40.00', 'Bread 30.00']);
  });
});
