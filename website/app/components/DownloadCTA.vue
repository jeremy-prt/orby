<template>
  <section class="py-28 px-6 relative overflow-hidden">
    <div class="absolute inset-0 bg-linear-to-b from-white via-brand-overlay/8 to-brand-overlay/25 -z-10" />

    <!-- Decorative elements (mirrored from hero) -->
    <div class="absolute inset-0 -z-5 overflow-hidden pointer-events-none" style="mask-image: linear-gradient(to top, black 50%, transparent 100%); -webkit-mask-image: linear-gradient(to top, black 50%, transparent 100%)">
      <!-- Dot grid -->
      <svg class="absolute inset-0 w-full h-full opacity-[0.12]">
        <pattern id="dots-cta" x="0" y="0" width="24" height="24" patternUnits="userSpaceOnUse">
          <circle cx="2" cy="2" r="1.2" fill="#C25DB0" />
        </pattern>
        <rect width="100%" height="100%" fill="url(#dots-cta)" />
      </svg>

      <!-- Ring bottom-left -->
      <svg class="absolute -bottom-32 -left-32 w-[350px] h-[350px] opacity-22" viewBox="0 0 350 350" fill="none">
        <circle cx="175" cy="175" r="140" stroke="#E2B6D5" stroke-width="1" />
        <circle cx="175" cy="175" r="90" stroke="#E2B6D5" stroke-width="0.5" />
      </svg>
    </div>

    <div class="max-w-2xl mx-auto text-center">
      <h2 class="text-4xl md:text-5xl font-extrabold tracking-tight mb-5">
        {{ t('cta.title1') }}
        <span class="text-transparent bg-clip-text bg-linear-to-r from-brand to-brand-accent">{{ t('cta.title2') }}</span> ?
      </h2>
      <p class="text-gray-500 text-lg mb-10">{{ t('cta.subtitle') }}</p>

      <div class="flex flex-col sm:flex-row items-center justify-center gap-3">
        <a
          href="https://github.com/jeremy-prt/orby/releases/latest/download/Orby.dmg"
          
          class="px-8 py-4 bg-brand hover:bg-brand-dark text-white font-semibold rounded-full shadow-lg shadow-brand/25 hover:shadow-xl hover:shadow-brand/35 transition-all text-base flex items-center gap-2 group"
        >
          {{ t('cta.download') }}
        </a>
        <a
          href="https://github.com/jeremy-prt/orby"
          target="_blank"
          class="px-8 py-4 bg-white hover:bg-gray-50 text-gray-700 font-medium rounded-full border border-gray-200 shadow-sm hover:shadow transition-all text-sm flex items-center gap-2"
        >
          <Icon name="mdi:github" class="text-lg" />
          {{ t('cta.github') }}
        </a>
      </div>

      <p class="mt-6 text-xs text-gray-400">{{ t('cta.requires') }}</p>
    </div>
  </section>
</template>

<script setup>
const { t } = useI18n()
</script>
