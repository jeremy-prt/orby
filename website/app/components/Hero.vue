<template>
  <div>
    <!-- Hero: full viewport on desktop, auto on mobile -->
    <section class="relative min-h-[70vh] md:min-h-screen flex flex-col items-center justify-center px-6 py-24 md:py-0">
      <div class="absolute inset-0 bg-linear-to-b from-brand-overlay/25 via-brand-overlay/8 to-white -z-10" />

      <!-- Decorative elements with fade-out at bottom -->
      <div class="absolute inset-0 -z-5 overflow-hidden pointer-events-none" style="mask-image: linear-gradient(to bottom, black 50%, transparent 100%); -webkit-mask-image: linear-gradient(to bottom, black 50%, transparent 100%)">
        <!-- Dot grid -->
        <svg class="absolute inset-0 w-full h-full opacity-[0.12]">
          <pattern id="dots" x="0" y="0" width="24" height="24" patternUnits="userSpaceOnUse">
            <circle cx="2" cy="2" r="1.2" fill="#C25DB0" />
          </pattern>
          <rect width="100%" height="100%" fill="url(#dots)" />
        </svg>

        <!-- Ring bottom-left -->
        <svg class="absolute -bottom-16 -left-16 w-[300px] h-[300px] opacity-20" viewBox="0 0 300 300" fill="none">
          <circle cx="150" cy="150" r="120" stroke="#E2B6D5" stroke-width="1" />
          <circle cx="150" cy="150" r="70" stroke="#E2B6D5" stroke-width="0.5" />
        </svg>
      </div>

      <div class="text-center w-full max-w-4xl">
        <h1 class="text-5xl md:text-6xl font-extrabold tracking-tight leading-tight mb-5">
          {{ t('hero.title1') }}
          <span class="text-transparent bg-clip-text bg-linear-to-r from-brand to-brand-accent">{{ t('hero.title2') }}</span>
        </h1>

        <p class="text-lg md:text-xl text-gray-500 max-w-2xl mx-auto mb-10 leading-relaxed">
          {{ t('hero.subtitle') }}
        </p>

        <div class="flex flex-col sm:flex-row items-center justify-center gap-3">
          <a
            href="https://github.com/jeremy-prt/orby/releases/latest/download/Orby.dmg"
            
            class="px-7 py-3.5 bg-brand hover:bg-brand-dark text-white font-semibold rounded-full shadow-lg shadow-brand/20 hover:shadow-xl hover:shadow-brand/30 transition-all text-sm"
          >
            {{ t('hero.cta') }}
          </a>
          <NuxtLink
            to="/setup"
            class="px-7 py-3.5 bg-white hover:bg-gray-50 text-gray-800 font-semibold rounded-full border border-gray-200 shadow-sm hover:shadow transition-all text-sm flex items-center gap-2"
          >
            <Icon name="mdi:help-circle-outline" class="text-lg" />
            {{ t('hero.setup') }}
          </NuxtLink>
        </div>
      </div>
    </section>

    <!-- Mockup: pins when visible (desktop only), scroll scales -->
    <section ref="mockupSection" class="relative flex items-center justify-center py-10 md:py-20 px-6 md:min-h-[80vh]">
      <div class="max-w-3xl w-full mx-auto">
        <div ref="mockup" class="rounded-2xl overflow-hidden shadow-2xl shadow-black/15 border border-gray-200/50 bg-gray-100 will-change-transform origin-center">
          <!-- macOS title bar -->
          <div class="flex items-center gap-2 px-4 py-3 bg-brand-overlay/20">
            <span class="w-3 h-3 rounded-full bg-[#ff5f57]" />
            <span class="w-3 h-3 rounded-full bg-[#febd2e]" />
            <span class="w-3 h-3 rounded-full bg-[#28c840]" />
          </div>
          <!-- Placeholder — replace with video when ready -->
          <div class="w-full aspect-video bg-brand-overlay/20 flex items-center justify-center">
            <Icon name="mdi:play-circle-outline" class="text-5xl text-brand/20" />
          </div>
        </div>
      </div>
    </section>
  </div>
</template>

<script setup>
import { gsap } from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'

const { t } = useI18n()

const mockupSection = ref(null)
const mockup = ref(null)

onMounted(() => {
  gsap.registerPlugin(ScrollTrigger)

  const isMobile = window.innerWidth < 768

  // No pin/scale on mobile — just show the mockup normally
  if (!isMobile) {
    gsap.to(mockup.value, {
      scale: 1.3,
      ease: 'power1.inOut',
      scrollTrigger: {
        trigger: mockupSection.value,
        start: 'center center',
        end: '+=80%',
        scrub: true,
        pin: true,
        anticipatePin: 1,
        invalidateOnRefresh: true,
      }
    })
  }
})

onUnmounted(() => {
  ScrollTrigger.getAll().forEach(st => st.kill())
})
</script>
