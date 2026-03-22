<template>
  <main>
    <Hero />
    <FeaturesGrid />
    <FeatureSection
      :title="t('section.capture.title')"
      :description="t('section.capture.desc')"
    />
    <FeatureSection
      :title="t('section.editor.title')"
      :description="t('section.editor.desc')"
      reversed
    />
    <FeatureSection
      :title="t('section.ocr.title')"
      :description="t('section.ocr.desc')"
    />
    <FeatureSection
      :title="t('section.history.title')"
      :description="t('section.history.desc')"
      reversed
    />
    <FeatureSection
      :title="t('section.background.title')"
      :description="t('section.background.desc')"
    />
    <!-- <Shortcuts /> -->
    <ChangelogSection />
    <DownloadCTA />
  </main>
</template>

<script setup>
const { t } = useI18n()
</script>
