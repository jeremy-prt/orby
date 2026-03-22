<template>
    <header
        :class="[
            'fixed top-4 left-1/2 -translate-x-1/2 z-50 transition-all duration-300',
            scrolled ? 'top-2' : 'top-4',
        ]"
    >
        <nav
            :class="[
                'flex items-center gap-6 px-6 py-3 rounded-full border transition-all duration-1000',
                scrolled
                    ? 'bg-white/60 backdrop-blur-xl border-gray-200/60 shadow-lg shadow-black/5'
                    : 'bg-transparent border-transparent',
            ]"
        >
            <a href="#" class="flex items-center gap-2 font-bold text-lg">
                <img src="/logo.svg" alt="Orby" class="w-7 h-7" />
                <span>Orby</span>
            </a>

            <div
                class="hidden md:flex items-center gap-5 text-sm font-medium text-gray-600"
            >
                <a
                    href="#features"
                    class="hover:text-brand transition-colors"
                    >{{ t("nav.features") }}</a
                >
                <a
                    href="#changelog"
                    class="hover:text-brand transition-colors"
                    >{{ t("nav.changelog") }}</a
                >
                <a
                    href="https://github.com/jeremy-prt/orby"
                    target="_blank"
                    class="hover:text-brand transition-colors flex items-center gap-1.5"
                >
                    <Icon name="mdi:github" class="text-base" />
                    GitHub
                    <span
                        v-if="stars !== null"
                        class="flex items-center gap-0.5 text-xs text-gray-400"
                    >
                        <Icon name="mdi:star" class="text-xs text-amber-400" />
                        {{ stars }}
                    </span>
                </a>
            </div>

            <!-- Download button: hidden on mobile -->
            <a
                href="https://github.com/jeremy-prt/orby/releases/latest/download/Orby.dmg"
                
                class="hidden md:inline-flex ml-2 px-5 py-2 bg-brand hover:bg-brand-dark text-white text-sm font-semibold rounded-full transition-all hover:shadow-lg hover:shadow-brand/20"
            >
                {{ t("nav.download") }}
            </a>

            <!-- Burger button: mobile only -->
            <button
                class="md:hidden ml-1 flex items-center"
                @click="mobileOpen = !mobileOpen"
            >
                <Icon
                    :name="mobileOpen ? 'mdi:close' : 'mdi:menu'"
                    class="text-xl"
                />
            </button>
        </nav>
    </header>

    <!-- Mobile slide-in panel -->
    <Teleport to="body">
        <!-- Backdrop -->
        <Transition name="fade">
            <div
                v-if="mobileOpen"
                class="fixed inset-0 bg-black/30 backdrop-blur-sm z-[60] md:hidden"
                @click="mobileOpen = false"
            />
        </Transition>

        <!-- Panel -->
        <Transition name="slide">
            <div
                v-if="mobileOpen"
                class="fixed top-0 right-0 h-full w-72 bg-white shadow-2xl z-[70] md:hidden flex flex-col"
            >
                <!-- Panel header -->
                <div
                    class="flex items-center justify-between px-6 py-5 border-b border-gray-100"
                >
                    <div class="flex items-center gap-2 font-bold text-lg">
                        <img src="/logo.svg" alt="Orby" class="w-6 h-6" />
                        <span>Orby</span>
                    </div>
                    <button
                        @click="mobileOpen = false"
                        class="p-1 rounded-lg hover:bg-gray-100 transition-colors"
                    >
                        <Icon name="mdi:close" class="text-xl text-gray-500" />
                    </button>
                </div>

                <!-- Panel links -->
                <div class="flex flex-col px-6 py-6 gap-1">
                    <a
                        href="#features"
                        class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 font-medium hover:bg-gray-50 transition-colors"
                        @click="mobileOpen = false"
                    >
                        <Icon
                            name="mdi:view-grid-outline"
                            class="text-lg text-brand"
                        />
                        {{ t("nav.features") }}
                    </a>
                    <a
                        href="#changelog"
                        class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 font-medium hover:bg-gray-50 transition-colors"
                        @click="mobileOpen = false"
                    >
                        <Icon
                            name="mdi:text-box-outline"
                            class="text-lg text-brand"
                        />
                        {{ t("nav.changelog") }}
                    </a>
                    <a
                        href="https://github.com/jeremy-prt/orby"
                        target="_blank"
                        class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 font-medium hover:bg-gray-50 transition-colors"
                    >
                        <Icon name="mdi:github" class="text-lg text-brand" />
                        GitHub
                        <span
                            v-if="stars !== null"
                            class="flex items-center gap-0.5 text-xs text-gray-400 ml-auto"
                        >
                            <Icon
                                name="mdi:star"
                                class="text-xs text-amber-400"
                            />
                            {{ stars }}
                        </span>
                    </a>
                    <NuxtLink
                        to="/setup"
                        class="flex items-center gap-3 px-4 py-3 rounded-xl text-gray-700 font-medium hover:bg-gray-50 transition-colors"
                        @click="mobileOpen = false"
                    >
                        <Icon
                            name="mdi:help-circle-outline"
                            class="text-lg text-brand"
                        />
                        {{ t("hero.setup") }}
                    </NuxtLink>
                </div>

                <!-- Panel footer -->
                <div class="mt-auto px-6 pb-8">
                    <p class="text-xs text-gray-400 text-center">
                        macOS 15+ · Desktop only
                    </p>
                </div>
            </div>
        </Transition>
    </Teleport>
</template>

<script setup lang="ts">
const { t } = useI18n();
const scrolled = ref(false);
const mobileOpen = ref(false);
const stars = ref<number | null>(null);

// Lock body scroll when panel is open
watch(mobileOpen, (open) => {
    if (import.meta.client) {
        document.body.style.overflow = open ? "hidden" : "";
    }
});

onMounted(async () => {
    window.addEventListener("scroll", () => {
        scrolled.value = window.scrollY > 20;
    });

    try {
        const res = await fetch("https://api.github.com/repos/jeremy-prt/orby");
        const data = await res.json();
        if (data.stargazers_count !== undefined) {
            stars.value = data.stargazers_count;
        }
    } catch {}
});
</script>

<style scoped>
/* Backdrop fade */
.fade-enter-active,
.fade-leave-active {
    transition: opacity 0.25s ease;
}
.fade-enter-from,
.fade-leave-to {
    opacity: 0;
}

/* Panel slide from right */
.slide-enter-active {
    transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}
.slide-leave-active {
    transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1);
}
.slide-enter-from,
.slide-leave-to {
    transform: translateX(100%);
}
</style>
