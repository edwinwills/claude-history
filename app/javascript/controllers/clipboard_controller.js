import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]

  async copy() {
    const text = this.sourceTarget.innerText
    try {
      await navigator.clipboard.writeText(text)
      const original = this.buttonTarget.innerText
      this.buttonTarget.innerText = "Copied"
      setTimeout(() => { this.buttonTarget.innerText = original }, 1200)
    } catch (e) {
      console.error("clipboard failed", e)
    }
  }
}
