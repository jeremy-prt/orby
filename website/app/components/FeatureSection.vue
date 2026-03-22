<template>
  <section class="py-20 px-6">
    <div
      :class="[
        'max-w-5xl mx-auto flex flex-col gap-10 items-center',
        reversed ? 'md:flex-row-reverse' : 'md:flex-row'
      ]"
    >
      <!-- Text -->
      <div class="flex-1 text-center md:text-left">
        <h2 class="text-3xl font-bold tracking-tight mb-4">{{ title }}</h2>
        <p class="text-gray-500 text-lg leading-relaxed">{{ description }}</p>
      </div>

      <!-- Video mockup -->
      <div class="flex-1 w-full max-w-lg">
        <div class="rounded-2xl overflow-hidden shadow-xl shadow-black/10 border border-gray-200/50 bg-gray-100">
          <!-- macOS title bar -->
          <div class="flex items-center gap-2 px-4 py-2.5 bg-brand-overlay/20">
            <span class="w-2.5 h-2.5 rounded-full bg-[#ff5f57]" />
            <span class="w-2.5 h-2.5 rounded-full bg-[#febd2e]" />
            <span class="w-2.5 h-2.5 rounded-full bg-[#28c840]" />
          </div>
          <video
            v-if="video"
            autoplay
            muted
            loop
            playsinline
            class="w-full"
            :poster="fallback"
          >
            <source :src="video" type="video/mp4" />
          </video>
          <img
            v-else-if="fallback"
            :src="fallback"
            :alt="title"
            class="w-full"
            loading="lazy"
          />
          <!-- Placeholder if no media -->
          <div v-else class="w-full aspect-video bg-brand-overlay/20 flex items-center justify-center">
            <Icon name="mdi:play-circle-outline" class="text-5xl text-brand/20" />
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
defineProps<{
  title: string
  description: string
  video?: string
  fallback?: string
  reversed?: boolean
}>()
</script>
