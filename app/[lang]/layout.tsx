import { locales } from '@/lib/i18n';
import { RootProvider } from 'fumadocs-ui/provider';
import type { ReactNode } from 'react';
import { Analytics } from '@/components/analytics';
import { GTMBody } from '@/components/analytics/gtm-body';
import { generatePageMetadata } from '@/lib/utils/metadata';
import StructuredDataComponent from '@/components/structured-data';
import { generateHomepageSchema } from '@/lib/utils/structured-data';
import { DefaultSearchDialog } from '@/components/docs/Search';
import { HomepageDarkMode } from './homepage-dark-mode';
import { AuthFormProvider } from '@/new-components/AuthForm/AuthFormProvider';
import { AuthForm } from '@/new-components/AuthForm';
import { HackathonButton } from '@/new-components/HackathonButton';
import { FORCED_DARK_MODE_PATHS } from './utils/is-forced-dark-mode';

export const metadata = generatePageMetadata();

const forcedDarkModeScript = `
(() => {
  const paths = ${JSON.stringify(FORCED_DARK_MODE_PATHS)};
  const pathname = window.location.pathname;
  const match = pathname.match(/^\\/(?:[a-z]{2}\\/|[a-z]{2}-[a-z]{2}\\/)?(.*)$/);
  const normalized = match ? '/' + match[1] : pathname;
  const shouldBeDark = paths.some(({ path, match: mode }) =>
    mode === 'full' ? normalized === path : normalized.startsWith(path)
  );
  document.documentElement.classList.toggle('dark', shouldBeDark);
})();
`;

// Generate static params for all supported languages
export async function generateStaticParams() {
  return locales.map((locale) => ({
    lang: locale.locale,
  }));
}

export default async function LocaleLayout({
  children,
  params,
}: {
  children: ReactNode;
  params: { lang: string };
}) {
  const htmlLang = params.lang || 'en';
  const homepageSchema = generateHomepageSchema(htmlLang);

  return (
    <html lang={htmlLang} className="font-sans" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: forcedDarkModeScript }} />

        {/* Favicon and App Icons */}
        <link
          rel="icon"
          type="image/png"
          href="/favicon/favicon-96x96.png"
          sizes="96x96"
        />
        <link rel="icon" type="image/svg+xml" href="/favicon/favicon.svg" />
        <link rel="shortcut icon" href="/favicon/favicon.ico" />
        <link
          rel="apple-touch-icon"
          sizes="180x180"
          href="/favicon/apple-touch-icon.png"
        />
        <link rel="manifest" href="/favicon/site.webmanifest" />

        {/* Viewport and Mobile Optimization */}
        <meta
          name="viewport"
          content="width=device-width, initial-scale=1, shrink-to-fit=no"
        />
        <meta name="mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="default" />
        <meta name="apple-mobile-web-app-title" content="Sealos" />
        <meta name="application-name" content="Sealos" />
        <meta name="msapplication-TileColor" content="#ffffff" />
        <meta name="theme-color" content="#ffffff" />

        <meta name="referrer" content="strict-origin-when-cross-origin" />

        {/* Performance and Resource Hints */}
        <link rel="dns-prefetch" href="https://www.googletagmanager.com" />
        <link rel="dns-prefetch" href="https://www.google-analytics.com" />
        <link rel="dns-prefetch" href="https://hm.baidu.com" />
        <link rel="dns-prefetch" href="https://analytics.sealos.in" />
        <link rel="dns-prefetch" href="https://engage.sealos.in" />

        {/* Preconnect to critical third-party domains */}
        <link rel="preconnect" href="https://www.googletagmanager.com" />
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link
          rel="preconnect"
          href="https://fonts.gstatic.com"
          crossOrigin="anonymous"
        />

        {/* Language and Locale */}
        <meta httpEquiv="Content-Language" content={htmlLang} />

        {/* Structured Data for SEO */}
        <StructuredDataComponent data={homepageSchema} />

        <Analytics />
      </head>
      <body className="flex min-h-screen max-w-[100vw] flex-col overflow-x-hidden">
        <GTMBody />
        <HomepageDarkMode />
        <AuthFormProvider>
          <RootProvider
            i18n={{
              locale: params.lang,
              locales,
              translations: {
                'zh-cn': {
                  search: '搜索',
                  nextPage: '下一页',
                  previousPage: '上一页',
                  lastUpdate: '最后更新于',
                  editOnGithub: '在 GitHub 上编辑',
                  searchNoResult: '没有找到相关内容',
                  toc: '本页导航',
                  tocNoHeadings: '本页没有导航',
                  chooseLanguage: '选择语言',
                },
              }[params.lang],
            }}
            theme={{
              forcedTheme: 'light',
              defaultTheme: 'light',
              enabled: false,
              enableSystem: false,
            }}
            search={{
              SearchDialog: DefaultSearchDialog,
            }}
          >
            {/* {needsDarkMode && (
              <div className="sticky top-0 z-50 flex h-auto w-full flex-col items-center justify-center bg-gradient-to-r from-white to-[#609CFF] px-4 py-2 text-zinc-900 sm:flex-row lg:h-12">
                <div className="flex flex-1 flex-col lg:w-fit lg:flex-none lg:flex-row">
                  <b className="text-center text-xs sm:text-start sm:text-sm lg:text-base">
                    🚀 Sealos Run Wild Hackathon (Jan 8 - 18):
                  </b>
                  <span className="text-center text-xs sm:text-start sm:text-sm lg:ml-1 lg:text-base">
                    Deploy your side project and win prizes! No PRs required.
                  </span>
                </div>
                <HackathonButton
                  href="https://memu.pro/hackathon/rules/sealos"
                  className="lg:ml-2"
                />
              </div>
            )} */}

            {children}
            <AuthForm />
          </RootProvider>
        </AuthFormProvider>
      </body>
    </html>
  );
}
