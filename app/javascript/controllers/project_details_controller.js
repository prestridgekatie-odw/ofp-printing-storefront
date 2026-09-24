import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.panelTargets.forEach((panel) => {
      const checkbox = this.checkboxFor(panel)
      this.syncPanel(panel, checkbox?.checked, false)
    })
  }

  toggle(event) {
    const checkbox = event.currentTarget
    const panel = this.panelTargets.find((candidate) => candidate.dataset.projectType === checkbox.value)
    if (panel) this.syncPanel(panel, checkbox.checked, !checkbox.checked)
  }

  updateOther(event) {
    this.updateOtherFields(event.currentTarget.closest(".project-detail-panel"))
  }

  checkboxFor(panel) {
    return this.element.querySelector(`input[name='quote_request[project_types][]'][value='${CSS.escape(panel.dataset.projectType)}']`)
  }

  syncPanel(panel, selected, reset) {
    const checkbox = this.checkboxFor(panel)
    const controls = panel.querySelectorAll("input, select, textarea")
    panel.hidden = !selected
    panel.setAttribute("aria-hidden", String(!selected))
    checkbox?.setAttribute("aria-expanded", String(Boolean(selected)))

    controls.forEach((control) => {
      control.disabled = !selected
      if (reset) {
        if (control.type === "checkbox" || control.type === "radio") control.checked = false
        else control.value = ""
      }
    })
    this.updateOtherFields(panel)
  }

  updateOtherFields(panel) {
    panel.querySelectorAll("[data-other-field-for]").forEach((field) => {
      const controllingField = field.dataset.otherFieldFor
      const selected = [...panel.querySelectorAll(`[data-project-details-field='${CSS.escape(controllingField)}']:checked`)].some((input) => input.value === "other")
      const input = field.querySelector("input")
      field.hidden = !selected
      input.disabled = !selected || panel.hidden
      input.required = selected && !panel.hidden
    })
  }
}