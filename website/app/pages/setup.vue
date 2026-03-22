<template>
  <main class="relative min-h-screen">
    <div class="absolute inset-0 bg-linear-to-b from-brand-overlay/30 via-brand-overlay/10 to-white -z-10" />

    <div class="max-w-2xl mx-auto px-6 pt-28 pb-20">
      <!-- Back link -->
      <NuxtLink to="/" class="inline-flex items-center gap-1.5 text-brand font-medium text-sm mb-10 hover:underline">
        <Icon name="mdi:arrow-left" class="text-base" />
        {{ t('setup.back') }}
      </NuxtLink>

      <h1 class="text-4xl font-extrabold tracking-tight mb-10">{{ t('setup.title') }}</h1>

      <!-- Steps -->
      <div class="flex flex-col gap-4">
        <SetupStep number="1" :title="t('setup.step1.title')">
          <p class="text-gray-600">{{ t('setup.step1.desc') }}</p>
          <a
            href="https://github.com/jeremy-prt/orby/releases/latest/download/Orby.dmg"
            
            class="inline-flex items-center gap-2 mt-3 px-5 py-2.5 bg-brand hover:bg-brand-dark text-white text-sm font-semibold rounded-xl transition-colors"
          >
            <Icon name="mdi:download" />
            {{ t('nav.download') }} .DMG
          </a>
        </SetupStep>

        <SetupStep number="2" :title="t('setup.step2.title')">
          <p class="text-gray-600 mb-3">{{ t('setup.step2.desc') }}</p>
          <div class="space-y-1.5">
            <p v-for="(step, i) in t('setup.step2.steps').split('\n')" :key="i" class="text-gray-600 text-sm">
              {{ step }}
            </p>
          </div>
          <!-- Video placeholder for setup demo -->
          <div class="mt-4 rounded-xl overflow-hidden border border-gray-200/60 shadow-md bg-linear-to-br from-brand-overlay/30 to-brand-overlay/10">
            <div class="w-full aspect-video flex items-center justify-center">
              <Icon name="mdi:play-circle-outline" class="text-5xl text-brand/30" />
            </div>
          </div>
          <p class="text-gray-400 text-xs mt-3 italic">{{ t('setup.step2.hint') }}</p>
          <p class="text-gray-400 text-xs mt-1 italic">{{ t('setup.step2.note') }}</p>
        </SetupStep>

        <SetupStep number="3" :title="t('setup.step3.title')">
          <p class="text-gray-600 mb-3">{{ t('setup.step3.desc') }}</p>
          <div class="space-y-1.5">
            <p v-for="(step, i) in t('setup.step3.steps').split('\n')" :key="i" class="text-gray-600 text-sm">
              {{ step }}
            </p>
          </div>
          <!-- Video placeholder for screen recording setup -->
          <div class="mt-4 rounded-xl overflow-hidden border border-gray-200/60 shadow-md bg-linear-to-br from-brand-overlay/30 to-brand-overlay/10">
            <div class="w-full aspect-video flex items-center justify-center">
              <Icon name="mdi:play-circle-outline" class="text-5xl text-brand/30" />
            </div>
          </div>
        </SetupStep>

        <SetupStep number="4" :title="t('setup.step4.title')">
          <p class="text-gray-600">{{ t('setup.step4.desc') }}</p>
        </SetupStep>

        <SetupStep number="5" :title="t('setup.step5.title')">
          <p class="text-gray-600">{{ t('setup.step5.desc') }}</p>
        </SetupStep>
      </div>

      <!-- Build from source -->
      <div class="mt-10 p-5 rounded-2xl bg-white/50 backdrop-blur-sm border border-white/60">
        <h3 class="font-bold text-sm mb-2 text-brand">{{ t('setup.build.title') }}</h3>
        <p class="text-gray-500 text-sm mb-3">{{ t('setup.build.desc') }}</p>
        <div class="bg-gray-900 text-gray-200 rounded-xl p-4 font-mono text-xs leading-relaxed">
          <span class="text-gray-500">$</span> git clone https://github.com/jeremy-prt/orby.git<br />
          <span class="text-gray-500">$</span> cd orby<br />
          <span class="text-gray-500">$</span> bash build-app.sh
        </div>
        <p class="text-gray-400 text-xs mt-2">{{ t('setup.build.requires') }}</p>
      </div>
    </div>
  </main>
</template>

<script setup>
const { t } = useI18n()
</script>
