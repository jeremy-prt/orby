<template>
  <section id="changelog" class="py-24 px-6">
    <div class="max-w-3xl mx-auto">
      <div class="text-center mb-14">
        <h2 class="text-3xl md:text-4xl font-bold tracking-tight mb-4">{{ t('changelog.title') }}</h2>
        <p class="text-gray-500 text-lg">{{ t('changelog.subtitle') }}</p>
      </div>

      <!-- Empty state -->
      <div v-if="loaded && !releases.length" class="text-center py-10">
        <div class="w-12 h-12 rounded-full bg-brand-overlay/30 flex items-center justify-center mx-auto mb-4">
          <Icon name="mdi:rocket-launch-outline" class="text-2xl text-brand" />
        </div>
        <p class="text-gray-400 text-sm">{{ t('changelog.noReleases') }}</p>
      </div>

      <!-- Timeline -->
      <div v-else-if="releases.length" class="relative">
        <!-- Vertical line -->
        <div class="absolute left-4 top-0 bottom-0 w-px bg-gray-200" />

        <div
          v-for="(release, i) in visibleReleases"
          :key="release.id"
          class="relative pl-12 pb-8 last:pb-0"
        >
          <!-- Dot -->
          <div class="absolute left-2.5 top-1 w-3 h-3 rounded-full border-2 border-brand bg-white" />

          <!-- Card -->
          <div class="bg-white rounded-xl border border-gray-100 shadow-sm p-5 hover:shadow-md transition-shadow">
            <div class="flex items-center gap-3 mb-1 flex-wrap">
              <span class="text-sm font-bold text-brand">{{ release.tag_name }}</span>
              <span class="text-xs text-gray-400">{{ formatDate(release.published_at) }}</span>
              <span v-if="release.prerelease" class="text-[10px] font-semibold px-2 py-0.5 rounded-full bg-amber-100 text-amber-700">Pre-release</span>
            </div>

            <!-- Collapsible body -->
            <div v-if="release.body" class="relative">
              <div
                :class="[
                  'text-xs text-gray-500 leading-relaxed overflow-hidden transition-all duration-300',
                  expandedIds.has(release.id) ? 'max-h-[2000px]' : 'max-h-24',
                  'duration-500 ease-in-out'
                ]"
                v-html="renderMarkdown(release.body)"
              />
              <!-- Fade overlay when collapsed -->
              <div
                v-if="!expandedIds.has(release.id) && hasLongBody(release.body)"
                class="absolute bottom-0 left-0 right-0 h-10 bg-linear-to-t from-white to-transparent"
              />
            </div>
            <button
              v-if="hasLongBody(release.body)"
              @click="toggleExpand(release.id)"
              class="text-[11px] font-medium text-brand hover:underline mt-1"
            >
              {{ expandedIds.has(release.id) ? t('changelog.showLess') : t('changelog.showMore') }}
            </button>
          </div>
        </div>
      </div>

      <!-- Show more releases -->
      <div v-if="releases.length > 3" class="text-center mt-10">
        <button
          @click="showAll = !showAll"
          class="px-5 py-2.5 text-sm font-medium text-brand border border-brand/20 rounded-full hover:bg-brand/5 transition-colors"
        >
          {{ showAll ? t('changelog.hideAll') : t('changelog.showAll') }}
        </button>
      </div>
    </div>
  </section>
</template>

<script setup>
const { t, lang } = useI18n()

const releases = ref([])
const showAll = ref(false)
const loaded = ref(false)
const expandedIds = ref(new Set())

const visibleReleases = computed(() =>
  showAll.value ? releases.value : releases.value.slice(0, 3)
)

function hasLongBody(body) {
  if (!body) return false
  return body.split('\n').length > 5 || body.length > 200
}

function toggleExpand(id) {
  const s = new Set(expandedIds.value)
  if (s.has(id)) s.delete(id)
  else s.add(id)
  expandedIds.value = s
}

function formatDate(dateStr) {
  if (!dateStr) return ''
  const langMap = { en: 'en-US', fr: 'fr-FR', es: 'es-ES', de: 'de-DE' }
  return new Date(dateStr).toLocaleDateString(langMap[lang.value] || 'en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })
}

function renderMarkdown(md) {
  return md
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/^### (.+)$/gm, '<h4 class="font-semibold text-gray-700 mt-2 mb-1">$1</h4>')
    .replace(/^## (.+)$/gm, '<h3 class="font-bold text-gray-800 mt-2 mb-1">$1</h3>')
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.+?)\*/g, '<em>$1</em>')
    .replace(/`(.+?)`/g, '<code class="px-1 py-0.5 bg-gray-100 rounded text-[11px]">$1</code>')
    .replace(/^[*-] (.+)$/gm, '<li class="ml-4 list-disc">$1</li>')
    .replace(/\n/g, '<br />')
}

onMounted(async () => {
  try {
    const res = await fetch('https://api.github.com/repos/jeremy-prt/orby/releases')
    if (res.ok) {
      const data = await res.json()
      releases.value = data
    }
  } catch {}

  loaded.value = true
})
</script>
