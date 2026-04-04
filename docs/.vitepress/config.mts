import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Echo Wiki',
  description: 'A generic, LLM-maintained knowledge base system',
  base: '/echo-wiki/',

  themeConfig: {
    nav: [
      { text: 'Guide', link: '/getting-started' },
      { text: 'Configuration', link: '/configuration' },
      { text: 'GitHub', link: 'https://github.com/echotheorylabsai/echo-wiki' }
    ],

    sidebar: [
      {
        text: 'Introduction',
        items: [
          { text: 'What is Echo Wiki?', link: '/' },
          { text: 'Getting Started', link: '/getting-started' },
        ]
      },
      {
        text: 'Usage',
        items: [
          { text: 'Configuration', link: '/configuration' },
          { text: 'Skills', link: '/skills' },
          { text: 'Validation & Linting', link: '/validation' },
          { text: 'Obsidian Integration', link: '/obsidian' },
        ]
      },
      {
        text: 'Reference',
        items: [
          { text: 'Frontmatter Schema', link: '/schema' },
          { text: 'Provider Support', link: '/providers' },
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/echotheorylabsai/echo-wiki' }
    ],

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright 2026 Echo Theory Labs'
    }
  }
})
