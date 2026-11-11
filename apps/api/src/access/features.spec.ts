import { adminEmails, roleFor } from './features.js';

describe('roleFor', () => {
  const admins = adminEmails(' Admin@Example.com, other@example.com ');

  it('promotes an address from ADMIN_EMAILS', () => {
    expect(roleFor('admin@example.com', null, admins)).toBe('admin');
    expect(roleFor('admin@example.com', 'member', admins)).toBe('admin');
  });

  it('keeps a stored admin and leaves everyone else a member', () => {
    expect(roleFor('person@example.com', 'admin', admins)).toBe('admin');
    expect(roleFor('person@example.com', null, admins)).toBe('member');
    expect(roleFor('person@example.com', 'member', admins)).toBe('member');
  });
});
