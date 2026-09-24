import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form",
    "step",
    "stepLabel",
    "stepName",
    "progressBar",
    "errorSummary",
    "phone",
    "phoneNote",
    "otherField",
    "otherInput",
    "projectTypeMessage"
  ]

  connect() {
    this.currentStep = Number(this.formTarget.dataset.initialStep || 1)
    this.stepNames = ["About you", "Your project", "Timing & delivery"]
    this.updateContactGuidance()
    this.toggleOther()
    this.updateView()

    if (this.hasErrorSummaryTarget) {
      this.errorSummaryTarget.focus()
    }
  }

  next(event) {
    event.preventDefault()
    if (!this.validateCurrentStep()) return

    this.currentStep = Math.min(this.currentStep + 1, this.stepTargets.length)
    this.updateView()
  }

  previous(event) {
    event.preventDefault()
    this.currentStep = Math.max(this.currentStep - 1, 1)
    this.updateView()
  }

  updateContactGuidance() {
    const selected = this.formTarget.querySelector("input[name='quote_request[preferred_contact_method]']:checked")
    const requiresPhone = selected && ["phone", "text"].includes(selected.value)

    this.phoneTarget.required = Boolean(requiresPhone)
    this.phoneNoteTarget.textContent = requiresPhone ? "A phone number is required for this contact preference." : "Required when phone or text is your preferred contact method."
  }

  toggleOther() {
    const otherCheckbox = this.formTarget.querySelector("input[name='quote_request[project_types][]'][value='Other']")
    const selected = Boolean(otherCheckbox?.checked)

    this.otherFieldTarget.hidden = !selected
    this.otherInputTarget.disabled = !selected
    this.otherInputTarget.required = selected
  }

  updateView() {
    this.stepTargets.forEach((step, index) => {
      const active = index + 1 === this.currentStep
      step.hidden = !active
      step.setAttribute("aria-hidden", String(!active))
    })

    this.stepLabelTarget.textContent = `Step ${this.currentStep} of ${this.stepTargets.length}`
    this.stepNameTarget.textContent = this.stepNames[this.currentStep - 1]
    this.progressBarTarget.style.width = `${(this.currentStep / this.stepTargets.length) * 100}%`
  }

  validateCurrentStep() {
    const currentStep = this.stepTargets[this.currentStep - 1]
    const controls = [...currentStep.querySelectorAll("input, select, textarea")]
      .filter((control) => !control.disabled && control.type !== "hidden")

    const invalidControl = controls.find((control) => !control.checkValidity())
    if (invalidControl) {
      invalidControl.reportValidity()
      return false
    }

    if (this.currentStep === 2) {
      const selectedProjectTypes = this.formTarget.querySelectorAll("input[name='quote_request[project_types][]']:checked").length
      if (selectedProjectTypes < 1 || selectedProjectTypes > 5) {
        this.projectTypeMessageTarget.textContent = "Choose one to five project types."
        this.projectTypeMessageTarget.setAttribute("role", "alert")
        this.formTarget.querySelector("input[name='quote_request[project_types][]']")?.focus()
        return false
      }

      this.projectTypeMessageTarget.textContent = "Choose one to five."
      this.projectTypeMessageTarget.removeAttribute("role")

      const missingDetailGroup = [...currentStep.querySelectorAll("[data-project-details-required='true']")]
        .find((group) => ![...group.querySelectorAll("input:not(:disabled)")].some((input) => input.checked))
      if (missingDetailGroup) {
        missingDetailGroup.querySelector("input:not(:disabled)")?.focus()
        return false
      }
    }

    return true
  }
}
