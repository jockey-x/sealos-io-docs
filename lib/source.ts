import { docs, meta, blog as blogPosts, aiQuickReference } from '@/.source';
import { createMDXSource } from 'fumadocs-mdx';
import { loader } from 'fumadocs-core/source';
import { Album, type LucideIcon } from 'lucide-react';
import { createElement } from 'react';
import { i18n } from '@/lib/i18n';

const docIcons: Record<string, LucideIcon> = {
  Album,
};

export const source = loader({
  i18n,
  baseUrl: '/docs',
  icon(icon) {
    if (!icon) {
      // You may set a default icon
      return;
    }

    const Icon = docIcons[icon];
    if (Icon) return createElement(Icon);
  },
  source: createMDXSource(docs, meta),
});

export const blog = loader({
  i18n,
  baseUrl: '/blog',
  source: createMDXSource(blogPosts, []),
});

export const faqSource = loader({
  i18n,
  baseUrl: '/ai-quick-reference',
  source: createMDXSource(aiQuickReference, []),
});
