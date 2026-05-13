import { blogAuthors, siteConfig } from '@/config/site';
import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { i18n, getLanguageSlug } from '@/lib/i18n';

const ogImageApi = `${siteConfig.url.base}/api/og`;

const siteName = siteConfig.name;

/**
 * The canonical domain for all pages.
 * All canonical URLs should point to sealos.io regardless of the current environment.
 * This ensures search engines recognize sealos.io as the authoritative version.
 */
const CANONICAL_DOMAIN = 'https://sealos.io';

type BlogImageFormat = 'svg-card' | 'svg-header' | 'png-og';

function getMetadataBlogImage(
  page: { slugs: string[]; locale?: string },
  format: BlogImageFormat = 'png-og',
) {
  const formatMap: Record<BlogImageFormat, string> = {
    'svg-card': '384x256.svg',
    'svg-header': '400x210.svg',
    'png-og': '1200x630@3x.png',
  };

  const locale = page.locale ?? 'en';
  const slug = page.slugs[0];
  const formatString = formatMap[format] ?? formatMap['png-og'];

  return `/api/blog/${encodeURIComponent(locale)}/${encodeURIComponent(
    slug,
  )}/thumbnail/${formatString}`;
}

export async function generateBlogMetadata(props: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { blog } = await import('@/lib/source');
  const params = await props.params;
  const page = blog.getPage([params.slug]);
  const isRootPage = !params.slug || params.slug.length === 0;

  if (!page && !isRootPage) notFound();

  let url = `${siteConfig.url.base}/blog`;
  let docTitle = 'Sealos Blog';
  let imageUrl = `${ogImageApi}/blog/${encodeURIComponent(docTitle)}`;
  let description = 'Sealos Blog';
  let keywords = ['Sealos', 'Blog'];

  if (page) {
    url = `${siteConfig.url.base}/blog/${page.slugs.join('/')}`;
    imageUrl = `${siteConfig.url.base}${getMetadataBlogImage(page)}`;
    docTitle = `${page.data.title} | Sealos Blog`;
    description = page.data.description;
  }

  return {
    metadataBase: new URL(siteConfig.url.base),
    title: {
      absolute: docTitle,
    },
    description: description,
    keywords: keywords,
    authors: page
      ? page.data.authors.map((author) => ({
          name: blogAuthors[author]?.name ?? author,
        }))
      : [{ name: siteConfig.author }],
    creator: siteConfig.author,
    publisher: siteConfig.author,
    robots: {
      index: true,
      follow: true,
      googleBot: {
        index: true,
        follow: true,
        'max-video-preview': -1,
        'max-image-preview': 'large',
        'max-snippet': -1,
      },
    },
    alternates: {
      canonical: `${CANONICAL_DOMAIN}/blog/${params.slug || ''}`,
      types: {
        'application/rss+xml': [
          {
            title: 'Sealos Blog',
            url: `${siteConfig.url.base}/rss.xml`,
          },
        ],
      },
    },
    openGraph: {
      url,
      title: docTitle,
      description: description,
      images: [
        {
          url: imageUrl,
          width: 1200,
          height: 630,
          alt: docTitle,
        },
      ],
      siteName: siteName,
      type: page ? 'article' : 'website',
      ...(page && {
        publishedTime: page.data.date,
        modifiedTime: page.data.lastModified || page.data.date,
        authors: page.data.authors.map(
          (author) => blogAuthors[author]?.name ?? author,
        ),
        section: 'Technology',
        tags: page.data.tags || keywords,
      }),
      locale: 'en_US',
    },
    twitter: {
      card: 'summary_large_image',
      site: siteConfig.twitterHandle,
      creator: siteConfig.twitterHandle,
      title: docTitle,
      description: description,
      images: [
        {
          url: imageUrl,
          alt: docTitle,
        },
      ],
    },
    category: page ? 'Technology' : undefined,
  };
}

export async function generateDocsMetadata({
  params,
}: {
  params: { lang: string; slug?: string[] };
}): Promise<Metadata> {
  const { source } = await import('@/lib/source');
  const page = source.getPage(params.slug, params.lang);
  if (!page) notFound();

  const fullPathTitle = page.slugs
    .map((s) => s.charAt(0).toUpperCase() + s.slice(1))
    .join(' > ');

  const url = `${siteConfig.url.base}/docs/${page.slugs.join('/')}`;
  const docsTitle = fullPathTitle
    ? fullPathTitle.toUpperCase()
    : 'Sealos Docs';
  const imageUrl = `${ogImageApi}/docs/${encodeURIComponent(docsTitle)}`;

  const isRootPage = !params.slug || params.slug.length === 0;
  const docTitle = isRootPage
    ? 'Sealos Docs'
    : `${fullPathTitle} | Sealos Docs`;

  return {
    metadataBase: new URL(siteConfig.url.base),
    title: {
      absolute: docTitle,
    },
    description: page.data.description,
    keywords: [
      'sealos',
      'documentation',
      'kubernetes',
      'cloud platform',
      'devops',
      'container',
    ],
    authors: [{ name: siteConfig.author }],
    creator: siteConfig.author,
    publisher: siteConfig.author,
    robots: {
      index: true,
      follow: true,
      googleBot: {
        index: true,
        follow: true,
        'max-video-preview': -1,
        'max-image-preview': 'large',
        'max-snippet': -1,
      },
    },
    alternates: {
      canonical: `${CANONICAL_DOMAIN}/docs/${page.slugs.join('/')}`,
      types: {
        'application/rss+xml': [
          {
            title: 'Sealos Blog',
            url: `${siteConfig.url.base}/rss.xml`,
          },
        ],
      },
    },
    openGraph: {
      url,
      title: docTitle,
      description: page.data.description,
      images: [
        {
          url: imageUrl,
          width: 1200,
          height: 630,
          alt: docTitle,
        },
      ],
      siteName: siteName,
      type: 'website',
      locale: params.lang === 'zh-cn' ? 'zh_CN' : 'en_US',
    },
    twitter: {
      card: 'summary_large_image',
      site: siteConfig.twitterHandle,
      creator: siteConfig.twitterHandle,
      title: docTitle,
      description: page.data.description,
      images: [
        {
          url: imageUrl,
          alt: docTitle,
        },
      ],
    },
    category: 'Documentation',
  } satisfies Metadata;
}

export function generatePageMetadata(
  options: {
    title?: string;
    description?: string;
    keywords?: string[];
    pathname?: string | null;
    lang?: string;
    author?: string;
    publishedTime?: string;
    modifiedTime?: string;
    section?: string;
    tags?: string[];
    ogType?: string;
  } = {},
): Metadata {
  const title = options.title
    ? `${options.title} | ${siteConfig.name}`
    : `${siteConfig.name} | ${siteConfig.tagline}`;
  const description = options.description
    ? options.description
    : siteConfig.description;
  const keywords = options.keywords ? options.keywords : siteConfig.keywords;
  const lang = options.lang || 'en';

  let ogType = options.ogType || 'website';
  let ogTitle = options.title || 'Sealos';

  // Construct the image URL using the new API structure: /api/og/[type]/[title]
  const imageUrl = `${ogImageApi}/${ogType}/${encodeURIComponent(ogTitle)}`;

  const hreflangLinks = options.pathname
    ? generateHreflangLinks(options.pathname)
    : [];
  const alternateLanguages: Record<string, string> = {};

  hreflangLinks.forEach((link) => {
    alternateLanguages[link.hrefLang] = link.href;
  });

  return {
    title: title,
    description: description,
    keywords: keywords,
    authors: options.author
      ? [{ name: options.author }]
      : [{ name: siteConfig.author }],
    creator: siteConfig.author,
    publisher: siteConfig.author,
    robots: {
      index: true,
      follow: true,
      googleBot: {
        index: true,
        follow: true,
        'max-video-preview': -1,
        'max-image-preview': 'large',
        'max-snippet': -1,
      },
    },
    verification: {
      google: process.env.GOOGLE_SITE_VERIFICATION,
    },
    alternates: {
      canonical: options.pathname
        ? `${CANONICAL_DOMAIN}${options.pathname}`
        : CANONICAL_DOMAIN,
      languages:
        Object.keys(alternateLanguages).length > 0
          ? alternateLanguages
          : undefined,
      types: {
        'application/rss+xml': [
          {
            title: 'Sealos Blog',
            url: `${siteConfig.url.base}/rss.xml`,
          },
        ],
      },
    },
    openGraph: {
      type: 'website',
      url: options.pathname
        ? `${siteConfig.url.base}${options.pathname}`
        : siteConfig.url.base,
      siteName: siteName,
      title: title,
      description: description,
      images: [
        {
          url: imageUrl,
          width: 1200,
          height: 630,
          alt: title,
        },
      ],
      locale: lang === 'zh-cn' ? 'zh_CN' : 'en_US',
    },
    twitter: {
      card: 'summary_large_image',
      title: title,
      description: description,
      images: [
        {
          url: imageUrl,
          alt: title,
        },
      ],
      creator: siteConfig.twitterHandle,
      site: siteConfig.twitterHandle,
    },
    metadataBase: new URL(siteConfig.url.base),
    category: options.section,
  };
}

/**
 * Generate metadata for product pages with enhanced SEO
 */
export function generateProductMetadata(options: {
  productName: string;
  description: string;
  pathname: string;
  lang?: string;
  features?: string[];
  category?: string;
}): Metadata {
  const lang = options.lang || 'en';
  const isZhCn = lang === 'zh-cn';

  const title = `${options.productName} | ${siteConfig.name}`;
  const keywords = [
    'sealos',
    options.productName.toLowerCase(),
    'cloud platform',
    'kubernetes',
    'container',
    'devops',
    'cloud native',
    ...(options.features || []),
  ];

  const imageUrl = `${ogImageApi}/products/${encodeURIComponent(
    options.productName.toLowerCase().replace(/\s+/g, '-'),
  )}`;

  // Generate hreflang links
  const hreflangLinks = generateHreflangLinks(options.pathname);
  const alternateLanguages: Record<string, string> = {};

  hreflangLinks.forEach((link) => {
    alternateLanguages[link.hrefLang] = link.href;
  });

  return {
    title: title,
    description: options.description,
    keywords: keywords,
    authors: [{ name: siteConfig.author }],
    creator: siteConfig.author,
    publisher: siteConfig.author,
    robots: {
      index: true,
      follow: true,
      googleBot: {
        index: true,
        follow: true,
        'max-video-preview': -1,
        'max-image-preview': 'large',
        'max-snippet': -1,
      },
    },
    alternates: {
      canonical: `${CANONICAL_DOMAIN}${options.pathname}`,
      languages:
        Object.keys(alternateLanguages).length > 0
          ? alternateLanguages
          : undefined,
      types: {
        'application/rss+xml': [
          {
            title: 'Sealos Blog',
            url: `${siteConfig.url.base}/rss.xml`,
          },
        ],
      },
    },
    openGraph: {
      type: 'website',
      url: `${siteConfig.url.base}${options.pathname}`,
      siteName: siteName,
      title: title,
      description: options.description,
      images: [
        {
          url: imageUrl,
          width: 1200,
          height: 630,
          alt: `${options.productName} - ${options.description}`,
        },
      ],
      locale: isZhCn ? 'zh_CN' : 'en_US',
    },
    twitter: {
      card: 'summary_large_image',
      title: title,
      description: options.description,
      images: [
        {
          url: imageUrl,
          alt: `${options.productName} - ${options.description}`,
        },
      ],
      creator: siteConfig.twitterHandle,
      site: siteConfig.twitterHandle,
    },
    metadataBase: new URL(siteConfig.url.base),
    category: options.category || 'Technology',
  };
}

/**
 * Get base URL based on language
 * @param lang - Language code ('en' or 'zh-cn')
 * @returns Base URL for the given language
 */
export function getBaseUrl(lang: string): string {
  const domainMap: Record<string, string> = {
    en: 'https://sealos.io',
    'zh-cn': 'https://sealos.run',
  };
  return domainMap[lang] || domainMap['en'];
}

/**
 * Get full page URL for social sharing and OpenGraph
 * For default locale (en), the language prefix is omitted
 * @param lang - Language code ('en' or 'zh-cn')
 * @param pagePath - Page path relative to root (e.g., '/blog/some-slug' or '/ai-quick-reference/some-slug')
 * @returns Full URL for the page
 */
export function getPageUrl(lang: string, pagePath: string): string {
  const baseUrl = getBaseUrl(lang);
  const langPrefix = getLanguageSlug(lang);
  // Ensure pagePath starts with /
  const normalizedPath = pagePath.startsWith('/') ? pagePath : `/${pagePath}`;
  return `${baseUrl}${langPrefix}${normalizedPath}`;
}

/**
 * Generate hreflang links for international SEO
 * @param currentPath - The current page path (without language prefix)
 * @returns Array of hreflang link objects
 */
export function generateHreflangLinks(
  currentPath: string = '',
): Array<{ hrefLang: string; href: string }> {
  const links: Array<{ hrefLang: string; href: string }> = [];

  // Clean the current path - remove leading slash and language prefix
  const cleanPath = currentPath
    .replace(/^\/?(en|zh-cn)\/?/, '')
    .replace(/^\/+/, '');

  // Generate hreflang links for each supported language
  i18n.languages.forEach((lang) => {
    const domain = getBaseUrl(lang);
    let href = domain;

    // Add path if it exists
    if (cleanPath) {
      href = `${domain}/${cleanPath}`;
    }

    // Add the hreflang link
    links.push({
      hrefLang: lang === 'zh-cn' ? 'zh-CN' : lang,
      href: href,
    });
  });

  // Add x-default (fallback to English domain)
  const defaultDomain = getBaseUrl('en');
  let defaultHref = defaultDomain;
  if (cleanPath) {
    defaultHref = `${defaultDomain}/${cleanPath}`;
  }

  links.push({
    hrefLang: 'x-default',
    href: defaultHref,
  });

  return links;
}
