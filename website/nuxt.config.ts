// https://nuxt.com/docs/api/configuration/nuxt-config
import tailwindcss from "@tailwindcss/vite";

export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },
  modules: ['@nuxt/icon'],
  css: ['./app/assets/css/main.css'],

  // Static generation for GitHub Pages
  ssr: false,
  nitro: {
    preset: 'github-pages'
  },

  app: {
    baseURL: process.env.NUXT_APP_BASE_URL || '/',
    head: {
      title: 'Orby — Screenshot tool for macOS',
      meta: [
        { name: 'description', content: 'A lightweight, free and open-source screenshot tool for macOS. Capture, annotate, beautify and share.' },
        { name: 'theme-color', content: '#964488' },
        { property: 'og:title', content: 'Orby — Screenshot tool for macOS' },
        { property: 'og:description', content: 'Capture, annotate, beautify and share your screenshots.' },
        { property: 'og:type', content: 'website' },
      ],
      link: [
        { rel: 'icon', type: 'image/x-icon', href: '/favicon.ico' },
        { rel: 'icon', type: 'image/png', href: '/favicon.png' }
      ]
    }
  },

  vite: {
    plugins: [
      tailwindcss(),
    ],
  },
})
