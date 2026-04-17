import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.focus()
    this.element.select()
  }

  cancel(event) {
    event.preventDefault()
    const form = this.element.closest("form")
    if (!form) return
    const cancelLink = form.querySelector("a.cancel")
    if (cancelLink) cancelLink.click()
  }
}
