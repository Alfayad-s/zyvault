'use client';

import { useState } from 'react';
import { featureTabs, features } from '../lib/site';

const paths = {
  mic: 'M12 14a3 3 0 0 0 3-3V6a3 3 0 0 0-6 0v5a3 3 0 0 0 3 3zm5-3a5 5 0 0 1-10 0H5a7 7 0 0 0 6 6.92V21h2v-3.08A7 7 0 0 0 19 11h-2z',
  bell: 'M12 22a2.5 2.5 0 0 0 2.45-2h-4.9A2.5 2.5 0 0 0 12 22zm7-6V11a7 7 0 0 0-5-6.71V3a2 2 0 1 0-4 0v1.29A7 7 0 0 0 5 11v5l-2 2v1h18v-1l-2-2z',
  target:
    'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm0 4a6 6 0 1 1 0 12 6 6 0 0 1 0-12zm0 3a3 3 0 1 0 0 6 3 3 0 0 0 0-6z',
  cal: 'M7 2h2v2h6V2h2v2h3v18H4V4h3V2zm11 8H6v10h12V10z',
  chat: 'M4 4h16v12H7l-3 3V4zm3 4v2h10V8H7zm0 4v2h7v-2H7z',
  lock: 'M7 10V7a5 5 0 0 1 10 0v3h1v12H6V10h1zm2 0h6V7a3 3 0 0 0-6 0v3z',
  spark: 'M12 2l1.6 5.2L19 9l-5.4 1.8L12 16l-1.6-5.2L5 9l5.4-1.8L12 2zm6 12l.8 2.2L21 17l-2.2.8L18 20l-.8-2.2L15 17l2.2-.8L18 14z',
  widget: 'M4 4h7v7H4V4zm9 0h7v5h-7V4zM4 13h7v7H4v-7zm9 3h7v4h-7v-4z',
  phone: 'M8 2h8a2 2 0 0 1 2 2v16a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2zm4 16.5a1.2 1.2 0 1 0 0 2.4 1.2 1.2 0 0 0 0-2.4z',
  file: 'M6 2h8l4 4v16H6V2zm8 1.5V7h3.5L14 3.5zM8 11h8v1.5H8V11zm0 3.5h8V16H8v-1.5z',
  chart: 'M4 19V5h2v12h12v2H4zm3-3 3-4 3 2 4-6 1.5 1-5.2 7.2-3.1-2.1L8.2 17 7 16z',
};

function Icon({ name }) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d={paths[name]} />
    </svg>
  );
}

export function FeatureTabs() {
  const [tab, setTab] = useState(featureTabs[0]);

  return (
    <>
      <div className="feature-tabs" role="tablist" aria-label="Feature groups">
        {featureTabs.map((name) => (
          <button
            key={name}
            type="button"
            role="tab"
            id={`feature-tab-${name}`}
            aria-selected={tab === name}
            aria-controls={`feature-panel-${name}`}
            onClick={() => setTab(name)}
          >
            {name}
          </button>
        ))}
      </div>
      {featureTabs.map((name) => (
        <div
          key={name}
          className="grid"
          role="tabpanel"
          id={`feature-panel-${name}`}
          aria-labelledby={`feature-tab-${name}`}
          hidden={tab !== name}
        >
          {features
            .filter((item) => item.tab === name)
            .map((item) => (
              <article key={item.title} id={item.icon === 'lock' ? 'privacy' : undefined}>
                <span className="icon">
                  <Icon name={item.icon} />
                </span>
                <h3>{item.title}</h3>
                <p>{item.body}</p>
              </article>
            ))}
        </div>
      ))}
    </>
  );
}
