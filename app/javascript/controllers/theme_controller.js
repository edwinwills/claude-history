import { Controller } from "@hotwired/stimulus"

const THEMES = ["light", "dark", "system"]
const STORAGE_KEY = "theme"

export default class extends Controller {
  static targets = ["option"]

  connect() {
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.mediaListener = () => { if (this.current === "system") this.apply() }
    this.mediaQuery.addEventListener("change", this.mediaListener)
    this.render()
  }

  disconnect() {
    this.mediaQuery.removeEventListener("change", this.mediaListener)
  }

  select(event) {
    const theme = event.currentTarget.dataset.themeValue
    if (!THEMES.includes(theme)) return
    localStorage.setItem(STORAGE_KEY, theme)
    this.apply()
    this.render()
  }

  get current() {
    const stored = localStorage.getItem(STORAGE_KEY)
    return THEMES.includes(stored) ? stored : "system"
  }

  apply() {
    const theme = this.current
    const isDark = theme === "dark" || (theme === "system" && this.mediaQuery.matches)
    document.documentElement.classList.toggle("dark", isDark)
    document.documentElement.dataset.theme = theme
  }

  render() {
    const theme = this.current
    this.optionTargets.forEach(btn => {
      const active = btn.dataset.themeValue === theme
      btn.setAttribute("aria-pressed", active ? "true" : "false")
      btn.classList.toggle("bg-accent", active)
      btn.classList.toggle("text-accent-foreground", active)
      btn.classList.toggle("text-muted-foreground", !active)
    })
  }
}
