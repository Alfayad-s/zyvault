import type { ConfigService } from '@nestjs/config';
import { ServiceUnavailableException } from '@nestjs/common';
import { VisionClient } from './vision.client.js';

function client(key?: string) {
  return new VisionClient({ get: () => key } as unknown as ConfigService);
}

function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

describe('VisionClient', () => {
  it('is off until the Vision key is set', () => {
    expect(client().configured()).toBe(false);
    expect(client('vision-key').configured()).toBe(true);
  });

  it('reads document text from a photo without putting the key in the URL', async () => {
    const fetch = vi.fn(() =>
      Promise.resolve(reply({ responses: [{ fullTextAnnotation: { text: 'Milk 40\nBread 30' } }] })),
    );
    vi.stubGlobal('fetch', fetch);

    await expect(client('vision-key').read({ mimeType: 'image/jpeg', data: 'abc' })).resolves.toBe(
      'Milk 40\nBread 30',
    );

    const [url, init] = fetch.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('https://vision.googleapis.com/v1/images:annotate');
    expect(new Headers(init.headers).get('x-goog-api-key')).toBe('vision-key');
    expect(url).not.toContain('vision-key');
    const body = JSON.parse(init.body as string) as {
      requests: { features: { type: string }[]; image: { content: string } }[];
    };
    expect(body.requests[0]?.features[0]?.type).toBe('DOCUMENT_TEXT_DETECTION');
    expect(body.requests[0]?.image.content).toBe('abc');
  });

  it('reads the first five pages of a PDF', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(() =>
        Promise.resolve(
          reply({
            responses: [
              {
                responses: [
                  { fullTextAnnotation: { text: 'Page one milk 40' } },
                  { fullTextAnnotation: { text: 'Page two bread 30' } },
                ],
              },
            ],
          }),
        ),
      ),
    );

    await expect(client('vision-key').read({ mimeType: 'application/pdf', data: 'pdf' })).resolves.toBe(
      'Page one milk 40\nPage two bread 30',
    );
    const init = vi.mocked(fetch).mock.calls[0]?.[1] as RequestInit;
    const body = JSON.parse(init.body as string) as { requests: { pages: number[] }[] };
    expect(body.requests[0]?.pages).toEqual([1, 2, 3, 4, 5]);
  });

  it('skips photo types Vision does not read', async () => {
    const fetch = vi.fn();
    vi.stubGlobal('fetch', fetch);
    await expect(client('vision-key').read({ mimeType: 'image/heic', data: 'abc' })).resolves.toBe('');
    expect(fetch).not.toHaveBeenCalled();
  });

  it('fails closed when Vision rejects the file', async () => {
    vi.stubGlobal('fetch', vi.fn(() => Promise.resolve(reply({ error: { message: 'bad key' } }, 403))));
    await expect(client('vision-key').read({ mimeType: 'image/png', data: 'abc' })).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });
});
