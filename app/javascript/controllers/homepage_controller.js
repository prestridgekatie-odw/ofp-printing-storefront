import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["navigation", "menuButton"]

  toggleMenu() {
    if (!this.hasNavigationTarget) return

    const isOpen = this.navigationTarget.classList.toggle("is-open")
    this.menuButtonTarget?.setAttribute("aria-expanded", String(isOpen))
  }

  closeMenu() {
    this.navigationTarget?.classList.remove("is-open")
    this.menuButtonTarget?.setAttribute("aria-expanded", "false")
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.closeMenu()
  }
}