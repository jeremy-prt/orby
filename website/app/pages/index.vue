<template>
  <main>
    <Hero />
    <FeaturesGrid />
    <FeatureSection
      :title="t('section.capture.title')"
      :description="t('section.capture.desc')"
      video="/videos/capture.mp4"
    />
    <FeatureSection
      :title="t('section.editor.title')"
      :description="t('section.editor.desc')"
      video="/videos/editor.mp4"
      reversed
    />
    <FeatureSection
      :title="t('section.ocr.title')"
      :description="t('section.ocr.desc')"
      video="/videos/ocr.mp4"
    />
    <FeatureSection
      :title="t('section.history.title')"
      :description="t('section.history.desc')"
      video="/videos/history.mp4"
      reversed
    />
    <FeatureSection
      :title="t('section.background.title')"
      :description="t('section.background.desc')"
      video="/videos/background.mp4"
    />
    <!-- <Shortcuts /> -->
    <ChangelogSection />
    <DownloadCTA />
  </main>
</template>

<script setup>
const { t } = useI18n()
</script>
